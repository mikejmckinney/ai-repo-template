export type EnemyKind = "chaser" | "striker" | "tank";

export type SimulationPhase = "running" | "paused" | "game-over";

export interface Vector2 {
  x: number;
  y: number;
}

export interface ArenaBounds {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

export interface SimulationConfig {
  width: number;
  height: number;
  arena: ArenaBounds;
  playerRadius: number;
  playerSpeed: number;
  playerMaxHealth: number;
  projectileSpeed: number;
  projectileRadius: number;
  projectileLifetimeTicks: number;
  fireCooldownTicks: number;
  spawnRadius: number;
  spawnRadiusJitter: number;
  wavePauseTicks: number;
}

export const DEFAULT_SIMULATION_CONFIG: SimulationConfig = {
  width: 1280,
  height: 720,
  arena: { left: 28, right: 1252, top: 28, bottom: 692 },
  playerRadius: 24,
  playerSpeed: 235,
  playerMaxHealth: 5,
  projectileSpeed: 640,
  projectileRadius: 7,
  projectileLifetimeTicks: 105,
  fireCooldownTicks: 8,
  spawnRadius: 300,
  spawnRadiusJitter: 80,
  wavePauseTicks: 42,
};

export interface InputFrame {
  up: boolean;
  down: boolean;
  left: boolean;
  right: boolean;
  fire: boolean;
  aimX: number;
  aimY: number;
}

export const EMPTY_INPUT: InputFrame = {
  up: false,
  down: false,
  left: false,
  right: false,
  fire: false,
  aimX: DEFAULT_SIMULATION_CONFIG.width / 2 + 1,
  aimY: DEFAULT_SIMULATION_CONFIG.height / 2,
};

export interface PlayerState {
  position: Vector2;
  facing: number;
  radius: number;
  speed: number;
  health: number;
  maxHealth: number;
  invulnerableTicks: number;
  fireCooldownTicks: number;
  hitFlashTicks: number;
}

export interface EnemyState {
  id: number;
  kind: EnemyKind;
  position: Vector2;
  radius: number;
  speed: number;
  health: number;
  maxHealth: number;
  contactDamage: number;
  scoreValue: number;
  phase: number;
  orbitDirection: number;
  hitFlashTicks: number;
  contactCooldownTicks: number;
}

export interface ProjectileState {
  id: number;
  position: Vector2;
  velocity: Vector2;
  radius: number;
  lifetimeTicks: number;
}

export type SimulationEvent =
  | { type: "shot"; projectile: ProjectileState }
  | { type: "enemy-hit"; enemyId: number; kind: EnemyKind; remainingHealth: number }
  | { type: "enemy-defeated"; enemyId: number; kind: EnemyKind; score: number }
  | { type: "player-hit"; health: number; damage: number }
  | { type: "wave-started"; wave: number; enemyCount: number }
  | { type: "game-over"; seed: string; finalTick: number };

export interface CompletionRecord {
  seed: string;
  finalTick: number;
}

export interface SimulationState {
  seed: string;
  tick: number;
  phase: SimulationPhase;
  wave: number;
  score: number;
  defeated: number;
  player: PlayerState;
  enemies: EnemyState[];
  projectiles: ProjectileState[];
  wavePauseTicksRemaining: number;
  lastDamageTick: number;
  completion: CompletionRecord | null;
}

interface EnemyProfile {
  radius: number;
  speed: number;
  health: number;
  contactDamage: number;
  scoreValue: number;
}

const ENEMY_PROFILES: Record<EnemyKind, EnemyProfile> = {
  chaser: { radius: 25, speed: 118, health: 1, contactDamage: 1, scoreValue: 100 },
  striker: { radius: 23, speed: 92, health: 2, contactDamage: 1, scoreValue: 160 },
  tank: { radius: 31, speed: 58, health: 4, contactDamage: 2, scoreValue: 280 },
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function distanceSquared(a: Vector2, b: Vector2): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return dx * dx + dy * dy;
}

function normalize(x: number, y: number): Vector2 {
  const length = Math.hypot(x, y);
  if (length < 0.0001) {
    return { x: 1, y: 0 };
  }
  return { x: x / length, y: y / length };
}

function hashSeed(value: string | number): number {
  const text = String(value);
  let hash = 2166136261;
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) || 0x6d2b79f5;
}

/** Small, deterministic PRNG kept inside the simulation boundary. */
export class SeededRandom {
  private value: number;

  public constructor(seed: string | number) {
    this.value = hashSeed(seed);
  }

  public next(): number {
    this.value = (this.value + 0x6d2b79f5) | 0;
    let result = Math.imul(this.value ^ (this.value >>> 15), 1 | this.value);
    result ^= result + Math.imul(result ^ (result >>> 7), 61 | result);
    return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
  }
}

function copyProjectile(projectile: ProjectileState): ProjectileState {
  return {
    id: projectile.id,
    position: { ...projectile.position },
    velocity: { ...projectile.velocity },
    radius: projectile.radius,
    lifetimeTicks: projectile.lifetimeTicks,
  };
}

export class VectorSiegeSimulation {
  public readonly config: SimulationConfig;

  private readonly random: SeededRandom;
  private nextEnemyId = 1;
  private nextProjectileId = 1;
  private events: SimulationEvent[] = [];

  public readonly state: SimulationState;

  public constructor(seed: string | number = "stage-1", config: SimulationConfig = DEFAULT_SIMULATION_CONFIG) {
    this.config = config;
    const seedText = String(seed);
    this.random = new SeededRandom(seedText);
    const startX = (config.arena.left + config.arena.right) / 2;
    const startY = (config.arena.top + config.arena.bottom) / 2;
    this.state = {
      seed: seedText,
      tick: 0,
      phase: "running",
      wave: 1,
      score: 0,
      defeated: 0,
      player: {
        position: { x: startX, y: startY },
        facing: 0,
        radius: config.playerRadius,
        speed: config.playerSpeed,
        health: config.playerMaxHealth,
        maxHealth: config.playerMaxHealth,
        invulnerableTicks: 0,
        fireCooldownTicks: 0,
        hitFlashTicks: 0,
      },
      enemies: [],
      projectiles: [],
      wavePauseTicksRemaining: 0,
      lastDamageTick: -1,
      completion: null,
    };

    this.spawnWave();
  }

  public pause(): void {
    if (this.state.phase === "running") {
      this.state.phase = "paused";
    }
  }

  public resume(): void {
    if (this.state.phase === "paused") {
      this.state.phase = "running";
    }
  }

  public getEvents(): SimulationEvent[] {
    return this.events.map((event) => {
      if (event.type === "shot") {
        return { ...event, projectile: copyProjectile(event.projectile) };
      }
      return { ...event } as SimulationEvent;
    });
  }

  public drainEvents(): SimulationEvent[] {
    const nextEvents = this.getEvents();
    this.events = [];
    return nextEvents;
  }

  public step(input: InputFrame = EMPTY_INPUT): void {
    if (this.state.phase !== "running") {
      return;
    }

    this.events = [];
    this.state.tick += 1;
    this.updatePlayer(input);
    this.updateProjectiles();
    this.updateEnemies();

    if (this.state.wavePauseTicksRemaining > 0) {
      this.state.wavePauseTicksRemaining -= 1;
      if (this.state.wavePauseTicksRemaining === 0) {
        this.spawnWave();
        this.events.push({ type: "wave-started", wave: this.state.wave, enemyCount: this.state.enemies.length });
      }
    }

    if (this.state.player.health <= 0 && this.state.phase === "running") {
      this.state.phase = "game-over";
      this.state.completion = { seed: this.state.seed, finalTick: this.state.tick };
      this.events.push({ type: "game-over", seed: this.state.seed, finalTick: this.state.tick });
    }
  }

  public nearestEnemy(): EnemyState | undefined {
    let nearest: EnemyState | undefined;
    let nearestDistance = Number.POSITIVE_INFINITY;
    for (const enemy of this.state.enemies) {
      const currentDistance = distanceSquared(enemy.position, this.state.player.position);
      if (currentDistance < nearestDistance) {
        nearest = enemy;
        nearestDistance = currentDistance;
      }
    }
    return nearest;
  }

  private updatePlayer(input: InputFrame): void {
    const movementX = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    const movementY = (input.down ? 1 : 0) - (input.up ? 1 : 0);
    const movement = normalize(movementX, movementY);
    const hasMovement = movementX !== 0 || movementY !== 0;
    const player = this.state.player;
    if (hasMovement) {
      player.position.x += movement.x * player.speed / 60;
      player.position.y += movement.y * player.speed / 60;
    }

    player.position.x = clamp(
      player.position.x,
      this.config.arena.left + player.radius,
      this.config.arena.right - player.radius,
    );
    player.position.y = clamp(
      player.position.y,
      this.config.arena.top + player.radius,
      this.config.arena.bottom - player.radius,
    );

    const aimX = Number.isFinite(input.aimX) ? input.aimX : player.position.x + 1;
    const aimY = Number.isFinite(input.aimY) ? input.aimY : player.position.y;
    if (Math.hypot(aimX - player.position.x, aimY - player.position.y) > 0.0001) {
      player.facing = Math.atan2(aimY - player.position.y, aimX - player.position.x);
    }

    if (player.invulnerableTicks > 0) {
      player.invulnerableTicks -= 1;
    }
    if (player.hitFlashTicks > 0) {
      player.hitFlashTicks -= 1;
    }
    if (player.fireCooldownTicks > 0) {
      player.fireCooldownTicks -= 1;
    }

    if (input.fire && player.fireCooldownTicks <= 0) {
      this.fireProjectile(aimX, aimY);
      player.fireCooldownTicks = this.config.fireCooldownTicks;
    }
  }

  private fireProjectile(aimX: number, aimY: number): void {
    const player = this.state.player;
    let direction = normalize(aimX - player.position.x, aimY - player.position.y);
    if (Math.abs(aimX - player.position.x) < 0.0001 && Math.abs(aimY - player.position.y) < 0.0001) {
      const target = this.nearestEnemy();
      direction = target
        ? normalize(target.position.x - player.position.x, target.position.y - player.position.y)
        : { x: Math.cos(player.facing), y: Math.sin(player.facing) };
    }

    const projectile: ProjectileState = {
      id: this.nextProjectileId,
      position: {
        x: player.position.x + direction.x * (player.radius + 8),
        y: player.position.y + direction.y * (player.radius + 8),
      },
      velocity: {
        x: direction.x * this.config.projectileSpeed / 60,
        y: direction.y * this.config.projectileSpeed / 60,
      },
      radius: this.config.projectileRadius,
      lifetimeTicks: this.config.projectileLifetimeTicks,
    };
    this.nextProjectileId += 1;
    this.state.projectiles.push(projectile);
    this.events.push({ type: "shot", projectile: copyProjectile(projectile) });
  }

  private updateProjectiles(): void {
    const survivors: ProjectileState[] = [];
    for (const projectile of this.state.projectiles) {
      projectile.position.x += projectile.velocity.x;
      projectile.position.y += projectile.velocity.y;
      projectile.lifetimeTicks -= 1;

      const insideArena = projectile.position.x >= this.config.arena.left
        && projectile.position.x <= this.config.arena.right
        && projectile.position.y >= this.config.arena.top
        && projectile.position.y <= this.config.arena.bottom;
      if (!insideArena || projectile.lifetimeTicks <= 0) {
        continue;
      }

      let hitEnemy = false;
      for (const enemy of this.state.enemies) {
        if (distanceSquared(projectile.position, enemy.position) > (projectile.radius + enemy.radius) ** 2) {
          continue;
        }

        hitEnemy = true;
        enemy.health -= 1;
        enemy.hitFlashTicks = 8;
        if (enemy.health <= 0) {
          this.state.score += enemy.scoreValue;
          this.state.defeated += 1;
          this.events.push({
            type: "enemy-defeated",
            enemyId: enemy.id,
            kind: enemy.kind,
            score: enemy.scoreValue,
          });
        } else {
          this.events.push({
            type: "enemy-hit",
            enemyId: enemy.id,
            kind: enemy.kind,
            remainingHealth: enemy.health,
          });
        }
        break;
      }

      if (!hitEnemy) {
        survivors.push(projectile);
      }
    }

    this.state.projectiles = survivors;
    this.state.enemies = this.state.enemies.filter((enemy) => enemy.health > 0);

    if (this.state.enemies.length === 0 && this.state.wavePauseTicksRemaining === 0) {
      this.state.wave += 1;
      this.state.wavePauseTicksRemaining = this.config.wavePauseTicks;
    }
  }

  private updateEnemies(): void {
    const player = this.state.player;
    for (const enemy of this.state.enemies) {
      if (enemy.hitFlashTicks > 0) {
        enemy.hitFlashTicks -= 1;
      }
      if (enemy.contactCooldownTicks > 0) {
        enemy.contactCooldownTicks -= 1;
      }

      const toPlayer = normalize(player.position.x - enemy.position.x, player.position.y - enemy.position.y);
      let direction = toPlayer;
      if (enemy.kind === "striker") {
        const orbit = Math.sin((this.state.tick + enemy.phase) / 24) * 0.72 * enemy.orbitDirection;
        const cos = Math.cos(orbit);
        const sin = Math.sin(orbit);
        direction = normalize(toPlayer.x * cos - toPlayer.y * sin, toPlayer.x * sin + toPlayer.y * cos);
      }

      enemy.position.x += direction.x * enemy.speed / 60;
      enemy.position.y += direction.y * enemy.speed / 60;
      enemy.position.x = clamp(enemy.position.x, this.config.arena.left + enemy.radius, this.config.arena.right - enemy.radius);
      enemy.position.y = clamp(enemy.position.y, this.config.arena.top + enemy.radius, this.config.arena.bottom - enemy.radius);

      if (distanceSquared(player.position, enemy.position) <= (player.radius + enemy.radius) ** 2) {
        if (player.invulnerableTicks <= 0 && enemy.contactCooldownTicks <= 0) {
          player.health = Math.max(0, player.health - enemy.contactDamage);
          player.invulnerableTicks = 48;
          player.hitFlashTicks = 18;
          this.state.lastDamageTick = this.state.tick;
          enemy.contactCooldownTicks = 48;
          this.events.push({ type: "player-hit", health: player.health, damage: enemy.contactDamage });

          const push = normalize(player.position.x - enemy.position.x, player.position.y - enemy.position.y);
          player.position.x = clamp(
            player.position.x + push.x * 8,
            this.config.arena.left + player.radius,
            this.config.arena.right - player.radius,
          );
          player.position.y = clamp(
            player.position.y + push.y * 8,
            this.config.arena.top + player.radius,
            this.config.arena.bottom - player.radius,
          );
        }
      }
    }
  }

  private spawnWave(): void {
    const enemyCount = Math.min(10, 3 + this.state.wave);
    for (let index = 0; index < enemyCount; index += 1) {
      const kind = this.enemyKindFor(this.state.wave, index);
      const profile = ENEMY_PROFILES[kind];
      const position = this.spawnPosition(index === 0 && this.state.wave === 1);
      this.state.enemies.push({
        id: this.nextEnemyId,
        kind,
        position,
        radius: profile.radius,
        speed: profile.speed + Math.min(32, this.state.wave * 3),
        health: profile.health + Math.floor((this.state.wave - 1) / 4),
        maxHealth: profile.health + Math.floor((this.state.wave - 1) / 4),
        contactDamage: profile.contactDamage,
        scoreValue: profile.scoreValue + Math.max(0, this.state.wave - 1) * 20,
        phase: Math.floor(this.random.next() * 360),
        orbitDirection: this.random.next() > 0.5 ? 1 : -1,
        hitFlashTicks: 0,
        contactCooldownTicks: 0,
      });
      this.nextEnemyId += 1;
    }
  }

  private enemyKindFor(wave: number, index: number): EnemyKind {
    if (wave === 1) {
      return ["chaser", "striker", "chaser", "tank"][index % 4] as EnemyKind;
    }
    const roll = (index + wave) % 5;
    if (roll === 0) {
      return "tank";
    }
    if (roll === 1 || roll === 3) {
      return "striker";
    }
    return "chaser";
  }

  private spawnPosition(forceFrontSpawn: boolean): Vector2 {
    const player = this.state.player.position;
    const radius = this.config.spawnRadius + this.random.next() * this.config.spawnRadiusJitter;
    const angle = forceFrontSpawn ? 0 : this.random.next() * Math.PI * 2;
    const rawPosition = {
      x: player.x + Math.cos(angle) * radius,
      y: player.y + Math.sin(angle) * radius,
    };
    const x = clamp(rawPosition.x, this.config.arena.left + 36, this.config.arena.right - 36);
    const y = clamp(rawPosition.y, this.config.arena.top + 36, this.config.arena.bottom - 36);
    if (Math.hypot(x - player.x, y - player.y) >= this.config.spawnRadius) {
      return { x, y };
    }

    // A corner can clamp a ring point inside the requested radius. Pick a perimeter
    // point in that rare case and keep the minimum-distance contract explicit.
    const side = Math.floor(this.random.next() * 4);
    if (side === 0) {
      return { x: this.config.arena.left + 40, y: player.y < this.config.height / 2 ? this.config.arena.bottom - 40 : this.config.arena.top + 40 };
    }
    if (side === 1) {
      return { x: this.config.arena.right - 40, y: player.y < this.config.height / 2 ? this.config.arena.bottom - 40 : this.config.arena.top + 40 };
    }
    if (side === 2) {
      return { x: player.x < this.config.width / 2 ? this.config.arena.right - 40 : this.config.arena.left + 40, y: this.config.arena.top + 40 };
    }
    return { x: player.x < this.config.width / 2 ? this.config.arena.right - 40 : this.config.arena.left + 40, y: this.config.arena.bottom - 40 };
  }
}
