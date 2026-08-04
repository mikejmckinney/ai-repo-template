export const GAME_WIDTH = 1280;
export const GAME_HEIGHT = 720;
export const FIXED_HZ = 60;
export const FIXED_DT = 1 / FIXED_HZ;

export const ARENA_BOUNDS = {
  left: 48,
  top: 72,
  right: GAME_WIDTH - 48,
  bottom: GAME_HEIGHT - 40,
};

export const PLAYER_RADIUS = 24;
export const PLAYER_SPEED = 225;
export const PLAYER_MAX_HEALTH = 3;
export const INVULNERABILITY_TICKS = 30;
export const ENEMY_SPAWN_RADIUS = 280;

export type SimulationStatus = "idle" | "running" | "paused" | "gameover";
export type EnemyKind = "chaser" | "striker" | "tank";

export interface SimulationInput {
  up?: boolean;
  down?: boolean;
  left?: boolean;
  right?: boolean;
  fire?: boolean;
  aimX?: number;
  aimY?: number;
  rapidFire?: boolean;
}

export interface PlayerState {
  x: number;
  y: number;
  angle: number;
  radius: number;
  speed: number;
  health: number;
  maxHealth: number;
  invulnerableUntilTick: number;
}

export interface BulletState {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  damage: number;
  ttl: number;
}

export interface EnemyState {
  id: number;
  kind: EnemyKind;
  x: number;
  y: number;
  radius: number;
  health: number;
  maxHealth: number;
  speed: number;
  contactDamage: number;
  points: number;
  phase: number;
}

export type SimulationEvent =
  | { type: "waveStart"; wave: number; count: number }
  | { type: "shot"; x: number; y: number; angle: number }
  | { type: "enemyHit"; enemyId: number; x: number; y: number; remainingHealth: number }
  | { type: "enemyDefeated"; enemyId: number; kind: EnemyKind; x: number; y: number; points: number }
  | { type: "playerHit"; x: number; y: number; health: number; damage: number }
  | { type: "gameOver"; score: number; wave: number; finalTick: number };

export interface CompletionRecord {
  seed: string;
  finalTick: number;
  score: number;
  wave: number;
}

export interface SimulationSnapshot {
  seed: string;
  tick: number;
  status: SimulationStatus;
  score: number;
  wave: number;
  player: PlayerState;
  bullets: BulletState[];
  enemies: EnemyState[];
  completion: CompletionRecord | null;
}

class SeededRandom {
  private state: number;

  public constructor(seed: number) {
    this.state = seed >>> 0 || 0x6d2b79f5;
  }

  public next(): number {
    let value = (this.state += 0x6d2b79f5);
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  }

  public range(min: number, max: number): number {
    return min + (max - min) * this.next();
  }

  public integer(min: number, max: number): number {
    return Math.floor(this.range(min, max + 1));
  }
}

function hashSeed(seed: number | string): number {
  if (typeof seed === "number" && Number.isFinite(seed)) {
    return seed >>> 0;
  }

  const source = String(seed);
  let hash = 2166136261;
  for (let index = 0; index < source.length; index += 1) {
    hash ^= source.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function seedLabel(seed: number | string): string {
  return typeof seed === "string" ? seed : String(seed >>> 0);
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function distanceSquared(ax: number, ay: number, bx: number, by: number): number {
  const dx = bx - ax;
  const dy = by - ay;
  return dx * dx + dy * dy;
}

function normalize(x: number, y: number): { x: number; y: number } {
  const length = Math.hypot(x, y);
  if (length < 0.0001) {
    return { x: 1, y: 0 };
  }
  return { x: x / length, y: y / length };
}

export class ArenaSimulation {
  public readonly seed: string;
  public tick = 0;
  public status: SimulationStatus = "idle";
  public score = 0;
  public wave = 0;
  public readonly player: PlayerState = {
    x: GAME_WIDTH / 2,
    y: GAME_HEIGHT / 2 + 18,
    angle: -Math.PI / 2,
    radius: PLAYER_RADIUS,
    speed: PLAYER_SPEED,
    health: PLAYER_MAX_HEALTH,
    maxHealth: PLAYER_MAX_HEALTH,
    invulnerableUntilTick: 0,
  };
  public readonly bullets: BulletState[] = [];
  public readonly enemies: EnemyState[] = [];
  public completion: CompletionRecord | null = null;

  private readonly random: SeededRandom;
  private nextEntityId = 1;
  private fireCooldownTicks = 0;

  public constructor(seed: number | string = "vector-siege-stage1") {
    this.seed = seedLabel(seed);
    this.random = new SeededRandom(hashSeed(seed));
  }

  public start(): SimulationEvent[] {
    this.tick = 0;
    this.status = "running";
    this.score = 0;
    this.wave = 0;
    this.player.x = GAME_WIDTH / 2;
    this.player.y = GAME_HEIGHT / 2 + 18;
    this.player.angle = -Math.PI / 2;
    this.player.health = PLAYER_MAX_HEALTH;
    this.player.invulnerableUntilTick = 0;
    this.bullets.length = 0;
    this.enemies.length = 0;
    this.completion = null;
    this.fireCooldownTicks = 0;
    this.nextEntityId = 1;
    return this.startNextWave();
  }

  public pause(): void {
    if (this.status === "running") {
      this.status = "paused";
    }
  }

  public resume(): void {
    if (this.status === "paused") {
      this.status = "running";
    }
  }

  public step(input: SimulationInput = {}): SimulationEvent[] {
    if (this.status !== "running") {
      return [];
    }

    this.tick += 1;
    const events: SimulationEvent[] = [];

    this.updatePlayer(input, events);
    this.updateBullets(events);
    this.updateEnemies(events);

    if (this.completion) {
      return events;
    }

    if (this.enemies.length === 0) {
      events.push(...this.startNextWave());
    }

    return events;
  }

  public spawnEnemy(kind: EnemyKind, x: number, y: number): EnemyState {
    const stats = this.statsFor(kind);
    const enemy: EnemyState = {
      id: this.nextEntityId++,
      kind,
      x,
      y,
      radius: stats.radius,
      health: stats.health,
      maxHealth: stats.health,
      speed: stats.speed,
      contactDamage: stats.contactDamage,
      points: stats.points,
      phase: this.random.range(0, Math.PI * 2),
    };
    this.enemies.push(enemy);
    return enemy;
  }

  public snapshot(): SimulationSnapshot {
    return {
      seed: this.seed,
      tick: this.tick,
      status: this.status,
      score: this.score,
      wave: this.wave,
      player: { ...this.player },
      bullets: this.bullets.map((bullet) => ({ ...bullet })),
      enemies: this.enemies.map((enemy) => ({ ...enemy })),
      completion: this.completion ? { ...this.completion } : null,
    };
  }

  private startNextWave(): SimulationEvent[] {
    this.wave += 1;
    const count = Math.min(12, 3 + this.wave);
    for (let index = 0; index < count; index += 1) {
      const kind = this.kindForWaveSlot(index);
      const spawn = this.spawnOutsideRadius();
      this.spawnEnemy(kind, spawn.x, spawn.y);
    }
    return [{ type: "waveStart", wave: this.wave, count }];
  }

  private kindForWaveSlot(index: number): EnemyKind {
    if (this.wave >= 3 && index % 5 === 0) {
      return "tank";
    }
    return index % 2 === 0 ? "chaser" : "striker";
  }

  private statsFor(kind: EnemyKind): {
    radius: number;
    health: number;
    speed: number;
    contactDamage: number;
    points: number;
  } {
    switch (kind) {
      case "tank":
        return {
          radius: 31,
          health: 5 + Math.floor(this.wave / 4),
          speed: 35 + this.wave * 2,
          contactDamage: 2,
          points: 300,
        };
      case "striker":
        return {
          radius: 24,
          health: 2 + Math.floor(this.wave / 5),
          speed: 64 + this.wave * 3,
          contactDamage: 1,
          points: 150,
        };
      case "chaser":
      default:
        return {
          radius: 23,
          health: 1 + Math.floor(this.wave / 6),
          speed: 82 + this.wave * 5,
          contactDamage: 1,
          points: 100,
        };
    }
  }

  private spawnOutsideRadius(): { x: number; y: number } {
    const minDistance = ENEMY_SPAWN_RADIUS;
    let best = { x: ARENA_BOUNDS.left + 30, y: ARENA_BOUNDS.top + 30 };
    let bestDistance = 0;

    for (let attempt = 0; attempt < 8; attempt += 1) {
      const side = this.random.integer(0, 3);
      const padding = 30;
      const candidate = {
        x:
          side === 0
            ? ARENA_BOUNDS.left + padding
            : side === 1
              ? ARENA_BOUNDS.right - padding
              : this.random.range(ARENA_BOUNDS.left + padding, ARENA_BOUNDS.right - padding),
        y:
          side === 2
            ? ARENA_BOUNDS.top + padding
            : side === 3
              ? ARENA_BOUNDS.bottom - padding
              : this.random.range(ARENA_BOUNDS.top + padding, ARENA_BOUNDS.bottom - padding),
      };
      const candidateDistance = Math.sqrt(
        distanceSquared(candidate.x, candidate.y, this.player.x, this.player.y),
      );
      if (candidateDistance > bestDistance) {
        best = candidate;
        bestDistance = candidateDistance;
      }
      if (candidateDistance >= minDistance) {
        return candidate;
      }
    }

    return best;
  }

  private updatePlayer(input: SimulationInput, events: SimulationEvent[]): void {
    let x = 0;
    let y = 0;
    if (input.left) x -= 1;
    if (input.right) x += 1;
    if (input.up) y -= 1;
    if (input.down) y += 1;

    const direction = normalize(x, y);
    if (x !== 0 || y !== 0) {
      this.player.x += direction.x * this.player.speed * FIXED_DT;
      this.player.y += direction.y * this.player.speed * FIXED_DT;
    }

    this.player.x = clamp(
      this.player.x,
      ARENA_BOUNDS.left + this.player.radius,
      ARENA_BOUNDS.right - this.player.radius,
    );
    this.player.y = clamp(
      this.player.y,
      ARENA_BOUNDS.top + this.player.radius,
      ARENA_BOUNDS.bottom - this.player.radius,
    );

    if (input.aimX !== undefined && input.aimY !== undefined) {
      this.player.angle = Math.atan2(input.aimY - this.player.y, input.aimX - this.player.x);
    }

    if (this.fireCooldownTicks > 0) {
      this.fireCooldownTicks -= 1;
    }
    if (input.fire && this.fireCooldownTicks <= 0) {
      this.fireCooldownTicks = input.rapidFire ? 5 : 9;
      const directionToAim = this.resolveAim(input);
      this.player.angle = Math.atan2(directionToAim.y, directionToAim.x);
      const muzzleDistance = this.player.radius + 9;
      this.bullets.push({
        id: this.nextEntityId++,
        x: this.player.x + directionToAim.x * muzzleDistance,
        y: this.player.y + directionToAim.y * muzzleDistance,
        vx: directionToAim.x * 650,
        vy: directionToAim.y * 650,
        radius: 5,
        damage: 1,
        ttl: 75,
      });
      events.push({
        type: "shot",
        x: this.player.x,
        y: this.player.y,
        angle: this.player.angle,
      });
    }
  }

  private resolveAim(input: SimulationInput): { x: number; y: number } {
    const aimX = input.aimX ?? this.player.x + Math.cos(this.player.angle) * 100;
    const aimY = input.aimY ?? this.player.y + Math.sin(this.player.angle) * 100;
    if (distanceSquared(aimX, aimY, this.player.x, this.player.y) > 36) {
      return normalize(aimX - this.player.x, aimY - this.player.y);
    }

    const nearest = this.enemies.reduce<EnemyState | null>((candidate, enemy) => {
      if (!candidate) return enemy;
      return distanceSquared(this.player.x, this.player.y, enemy.x, enemy.y) <
        distanceSquared(this.player.x, this.player.y, candidate.x, candidate.y)
        ? enemy
        : candidate;
    }, null);
    if (nearest) {
      return normalize(nearest.x - this.player.x, nearest.y - this.player.y);
    }
    return normalize(Math.cos(this.player.angle), Math.sin(this.player.angle));
  }

  private updateBullets(events: SimulationEvent[]): void {
    for (let bulletIndex = this.bullets.length - 1; bulletIndex >= 0; bulletIndex -= 1) {
      const bullet = this.bullets[bulletIndex];
      bullet.x += bullet.vx * FIXED_DT;
      bullet.y += bullet.vy * FIXED_DT;
      bullet.ttl -= 1;

      const outside =
        bullet.x < ARENA_BOUNDS.left ||
        bullet.x > ARENA_BOUNDS.right ||
        bullet.y < ARENA_BOUNDS.top ||
        bullet.y > ARENA_BOUNDS.bottom;
      if (outside || bullet.ttl <= 0) {
        this.bullets.splice(bulletIndex, 1);
        continue;
      }

      let hit = false;
      for (let enemyIndex = this.enemies.length - 1; enemyIndex >= 0; enemyIndex -= 1) {
        const enemy = this.enemies[enemyIndex];
        const hitRadius = bullet.radius + enemy.radius;
        if (distanceSquared(bullet.x, bullet.y, enemy.x, enemy.y) > hitRadius * hitRadius) {
          continue;
        }

        enemy.health -= bullet.damage;
        hit = true;
        if (enemy.health <= 0) {
          this.enemies.splice(enemyIndex, 1);
          this.score += enemy.points;
          events.push({
            type: "enemyDefeated",
            enemyId: enemy.id,
            kind: enemy.kind,
            x: enemy.x,
            y: enemy.y,
            points: enemy.points,
          });
        } else {
          events.push({
            type: "enemyHit",
            enemyId: enemy.id,
            x: enemy.x,
            y: enemy.y,
            remainingHealth: enemy.health,
          });
        }
        break;
      }

      if (hit) {
        this.bullets.splice(bulletIndex, 1);
      }
    }
  }

  private updateEnemies(events: SimulationEvent[]): void {
    for (const enemy of this.enemies) {
      const toPlayer = normalize(this.player.x - enemy.x, this.player.y - enemy.y);
      let direction = toPlayer;
      if (enemy.kind === "striker") {
        const perpendicular = { x: -toPlayer.y, y: toPlayer.x };
        const strafe = Math.sin(this.tick * 0.085 + enemy.phase) * 0.55;
        direction = normalize(toPlayer.x + perpendicular.x * strafe, toPlayer.y + perpendicular.y * strafe);
      }

      enemy.x += direction.x * enemy.speed * FIXED_DT;
      enemy.y += direction.y * enemy.speed * FIXED_DT;

      const contactDistance = enemy.radius + this.player.radius;
      if (
        distanceSquared(enemy.x, enemy.y, this.player.x, this.player.y) <=
        contactDistance * contactDistance
      ) {
        this.damagePlayer(enemy.contactDamage, events);
        const push = normalize(enemy.x - this.player.x, enemy.y - this.player.y);
        enemy.x = this.player.x + push.x * (contactDistance + 1);
        enemy.y = this.player.y + push.y * (contactDistance + 1);
      }
    }
  }

  private damagePlayer(damage: number, events: SimulationEvent[]): void {
    if (this.tick < this.player.invulnerableUntilTick || this.status !== "running") {
      return;
    }
    this.player.health = Math.max(0, this.player.health - damage);
    this.player.invulnerableUntilTick = this.tick + INVULNERABILITY_TICKS;
    events.push({
      type: "playerHit",
      x: this.player.x,
      y: this.player.y,
      health: this.player.health,
      damage,
    });

    if (this.player.health <= 0) {
      this.status = "gameover";
      this.completion = {
        seed: this.seed,
        finalTick: this.tick,
        score: this.score,
        wave: this.wave,
      };
      events.push({
        type: "gameOver",
        score: this.score,
        wave: this.wave,
        finalTick: this.tick,
      });
    }
  }
}
