export const SIMULATION_HZ = 60;
export const SIMULATION_DT = 1 / SIMULATION_HZ;

export type GamePhase = "running" | "paused" | "gameover";
export type EnemyKind = "chaser" | "striker" | "tank";

export interface InputFrame {
  moveX: number;
  moveY: number;
  aimX: number;
  aimY: number;
  fire: boolean;
}

export interface Vector2 {
  x: number;
  y: number;
}

export interface EnemyState extends Vector2 {
  id: number;
  kind: EnemyKind;
  health: number;
  maxHealth: number;
  radius: number;
  speed: number;
  orbitDirection: 1 | -1;
  contactCooldownTicks: number;
}

export interface ProjectileState extends Vector2 {
  id: number;
  vx: number;
  vy: number;
  radius: number;
  damage: number;
  lifetimeTicks: number;
}

export interface CompletedGameRecord {
  seed: string;
  finalTick: number;
  score: number;
  wave: number;
}

export interface SimulationSnapshot {
  seed: string;
  tick: number;
  phase: GamePhase;
  score: number;
  wave: number;
  player: {
    x: number;
    y: number;
    health: number;
    maxHealth: number;
    radius: number;
    invulnerableTicks: number;
  };
  enemies: EnemyState[];
  projectiles: ProjectileState[];
  shotsFired: number;
  enemiesDefeated: number;
  waveDelayTicks: number;
  completedGame: CompletedGameRecord | null;
}

export interface SimulationOptions {
  seed?: string | number;
  width?: number;
  height?: number;
  playerHealth?: number;
  spawnRadius?: number;
}

export interface SimulationEvent {
  type: "shot" | "enemy-hit" | "enemy-defeat" | "player-hit" | "wave-start" | "game-over";
  x: number;
  y: number;
  enemyKind?: EnemyKind;
  score?: number;
}

const DEFAULT_SEED = "VECTOR-SIEGE-STAGE-1";
const PLAYER_SPEED = 270;
const PLAYER_RADIUS = 24;
const PLAYER_MAX_HEALTH = 5;
const PLAYER_INVULNERABLE_TICKS = 60;
const PROJECTILE_SPEED = 760;
const PROJECTILE_RADIUS = 6;
const PROJECTILE_LIFETIME_TICKS = 90;
const FIRE_INTERVAL_TICKS = 8;
const WAVE_BREAK_TICKS = 45;
const ARENA_MARGIN = 48;

const ENEMY_DEFINITIONS: Record<EnemyKind, Omit<EnemyState, "id" | "x" | "y" | "orbitDirection" | "contactCooldownTicks">> = {
  chaser: {
    kind: "chaser",
    health: 1,
    maxHealth: 1,
    radius: 25,
    speed: 108,
  },
  striker: {
    kind: "striker",
    health: 1,
    maxHealth: 1,
    radius: 22,
    speed: 86,
  },
  tank: {
    kind: "tank",
    health: 3,
    maxHealth: 3,
    radius: 31,
    speed: 48,
  },
};

const ENEMY_SCORE: Record<EnemyKind, number> = {
  chaser: 100,
  striker: 150,
  tank: 300,
};

const clamp = (value: number, min: number, max: number): number => Math.min(max, Math.max(min, value));

const distanceSquared = (a: Vector2, b: Vector2): number => {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return dx * dx + dy * dy;
};

const normalize = (x: number, y: number): Vector2 => {
  const length = Math.hypot(x, y);
  return length > 0.0001 ? { x: x / length, y: y / length } : { x: 1, y: 0 };
};

const hashSeed = (seed: string | number): number => {
  if (typeof seed === "number" && Number.isFinite(seed)) {
    return seed >>> 0;
  }

  const text = String(seed);
  let hash = 2166136261;
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
};

class SeededRandom {
  private state: number;

  constructor(seed: string | number) {
    this.state = hashSeed(seed) || 0x9e3779b9;
  }

  next(): number {
    this.state = Math.imul(this.state ^ (this.state >>> 16), 2246822507);
    this.state = Math.imul(this.state ^ (this.state >>> 13), 3266489909);
    this.state ^= this.state >>> 16;
    return (this.state >>> 0) / 4294967296;
  }

  range(min: number, max: number): number {
    return min + (max - min) * this.next();
  }

  pick<T>(items: readonly T[]): T {
    return items[Math.floor(this.next() * items.length)] ?? items[0];
  }
}

export class ArenaSimulation {
  readonly width: number;
  readonly height: number;
  readonly playerMaxHealth: number;
  readonly spawnRadius: number;

  private rng: SeededRandom;
  private currentSeed: string;
  private phaseValue: GamePhase = "running";
  private tickValue = 0;
  private scoreValue = 0;
  private waveValue = 1;
  private playerValue: SimulationSnapshot["player"];
  private enemiesValue: EnemyState[] = [];
  private projectilesValue: ProjectileState[] = [];
  private nextEnemyId = 1;
  private nextProjectileId = 1;
  private fireCooldownTicks = 0;
  private waveDelayValue = 0;
  private shotsFiredValue = 0;
  private enemiesDefeatedValue = 0;
  private completedGameValue: CompletedGameRecord | null = null;
  private completionRecords: CompletedGameRecord[] = [];
  private eventsValue: SimulationEvent[] = [];

  constructor(options: SimulationOptions = {}) {
    this.width = options.width ?? 1280;
    this.height = options.height ?? 720;
    this.playerMaxHealth = options.playerHealth ?? PLAYER_MAX_HEALTH;
    this.spawnRadius = options.spawnRadius ?? 300;
    this.currentSeed = String(options.seed ?? DEFAULT_SEED);
    this.rng = new SeededRandom(this.currentSeed);
    this.playerValue = {
      x: this.width / 2,
      y: this.height / 2,
      health: this.playerMaxHealth,
      maxHealth: this.playerMaxHealth,
      radius: PLAYER_RADIUS,
      invulnerableTicks: 0,
    };
    this.spawnWave();
  }

  get phase(): GamePhase {
    return this.phaseValue;
  }

  get tick(): number {
    return this.tickValue;
  }

  get seed(): string {
    return this.currentSeed;
  }

  get completedGames(): readonly CompletedGameRecord[] {
    return this.completionRecords;
  }

  get events(): readonly SimulationEvent[] {
    return this.eventsValue;
  }

  step(input: InputFrame = { moveX: 0, moveY: 0, aimX: this.playerValue.x + 1, aimY: this.playerValue.y, fire: false }): void {
    this.eventsValue = [];
    if (this.phaseValue !== "running") {
      return;
    }

    this.tickValue += 1;
    this.fireCooldownTicks = Math.max(0, this.fireCooldownTicks - 1);
    this.playerValue.invulnerableTicks = Math.max(0, this.playerValue.invulnerableTicks - 1);
    this.movePlayer(input.moveX, input.moveY);

    if (input.fire && this.fireCooldownTicks === 0) {
      this.fire(input.aimX, input.aimY);
    }

    this.moveProjectiles();
    this.moveEnemies();
    this.resolveProjectileHits();
    this.resolveEnemyContacts();
    this.advanceWaveIfClear();
  }

  pause(): boolean {
    if (this.phaseValue !== "running") {
      return false;
    }
    this.phaseValue = "paused";
    return true;
  }

  resume(): boolean {
    if (this.phaseValue !== "paused") {
      return false;
    }
    this.phaseValue = "running";
    return true;
  }

  restart(seed: string | number = this.currentSeed): void {
    this.currentSeed = String(seed);
    this.rng = new SeededRandom(this.currentSeed);
    this.phaseValue = "running";
    this.tickValue = 0;
    this.scoreValue = 0;
    this.waveValue = 1;
    this.playerValue = {
      x: this.width / 2,
      y: this.height / 2,
      health: this.playerMaxHealth,
      maxHealth: this.playerMaxHealth,
      radius: PLAYER_RADIUS,
      invulnerableTicks: 0,
    };
    this.enemiesValue = [];
    this.projectilesValue = [];
    this.nextEnemyId = 1;
    this.nextProjectileId = 1;
    this.fireCooldownTicks = 0;
    this.waveDelayValue = 0;
    this.shotsFiredValue = 0;
    this.enemiesDefeatedValue = 0;
    this.completedGameValue = null;
    this.eventsValue = [];
    this.spawnWave();
  }

  applyDamage(amount = 1): boolean {
    if (this.phaseValue !== "running" || this.playerValue.invulnerableTicks > 0 || amount <= 0) {
      return false;
    }
    this.playerValue.health = Math.max(0, this.playerValue.health - amount);
    this.playerValue.invulnerableTicks = PLAYER_INVULNERABLE_TICKS;
    this.eventsValue.push({ type: "player-hit", x: this.playerValue.x, y: this.playerValue.y });
    if (this.playerValue.health === 0) {
      this.finishGame();
    }
    return true;
  }

  damageEnemy(enemyId: number, amount = 1): boolean {
    if (this.phaseValue !== "running" || amount <= 0) {
      return false;
    }
    const enemy = this.enemiesValue.find((candidate) => candidate.id === enemyId);
    if (!enemy) {
      return false;
    }
    enemy.health = Math.max(0, enemy.health - amount);
    this.eventsValue.push({ type: "enemy-hit", x: enemy.x, y: enemy.y, enemyKind: enemy.kind });
    if (enemy.health === 0) {
      this.defeatEnemy(enemy);
    }
    return true;
  }

  snapshot(): SimulationSnapshot {
    return {
      seed: this.currentSeed,
      tick: this.tickValue,
      phase: this.phaseValue,
      score: this.scoreValue,
      wave: this.waveValue,
      player: { ...this.playerValue },
      enemies: this.enemiesValue.map((enemy) => ({ ...enemy })),
      projectiles: this.projectilesValue.map((projectile) => ({ ...projectile })),
      shotsFired: this.shotsFiredValue,
      enemiesDefeated: this.enemiesDefeatedValue,
      waveDelayTicks: this.waveDelayValue,
      completedGame: this.completedGameValue ? { ...this.completedGameValue } : null,
    };
  }

  private movePlayer(moveX: number, moveY: number): void {
    const direction = normalize(clamp(moveX, -1, 1), clamp(moveY, -1, 1));
    const magnitude = Math.min(1, Math.hypot(clamp(moveX, -1, 1), clamp(moveY, -1, 1)));
    this.playerValue.x = clamp(
      this.playerValue.x + direction.x * PLAYER_SPEED * SIMULATION_DT * magnitude,
      ARENA_MARGIN + PLAYER_RADIUS,
      this.width - ARENA_MARGIN - PLAYER_RADIUS,
    );
    this.playerValue.y = clamp(
      this.playerValue.y + direction.y * PLAYER_SPEED * SIMULATION_DT * magnitude,
      ARENA_MARGIN + PLAYER_RADIUS,
      this.height - ARENA_MARGIN - PLAYER_RADIUS,
    );
  }

  private fire(aimX: number, aimY: number): void {
    const direction = normalize(aimX - this.playerValue.x, aimY - this.playerValue.y);
    const x = this.playerValue.x + direction.x * (PLAYER_RADIUS + 10);
    const y = this.playerValue.y + direction.y * (PLAYER_RADIUS + 10);
    this.projectilesValue.push({
      id: this.nextProjectileId,
      x,
      y,
      vx: direction.x * PROJECTILE_SPEED,
      vy: direction.y * PROJECTILE_SPEED,
      radius: PROJECTILE_RADIUS,
      damage: 1,
      lifetimeTicks: PROJECTILE_LIFETIME_TICKS,
    });
    this.nextProjectileId += 1;
    this.fireCooldownTicks = FIRE_INTERVAL_TICKS;
    this.shotsFiredValue += 1;
    this.eventsValue.push({ type: "shot", x, y });
  }

  private moveProjectiles(): void {
    this.projectilesValue = this.projectilesValue.filter((projectile) => {
      projectile.x += projectile.vx * SIMULATION_DT;
      projectile.y += projectile.vy * SIMULATION_DT;
      projectile.lifetimeTicks -= 1;
      return (
        projectile.lifetimeTicks > 0 &&
        projectile.x >= -projectile.radius &&
        projectile.x <= this.width + projectile.radius &&
        projectile.y >= -projectile.radius &&
        projectile.y <= this.height + projectile.radius
      );
    });
  }

  private moveEnemies(): void {
    for (const enemy of this.enemiesValue) {
      enemy.contactCooldownTicks = Math.max(0, enemy.contactCooldownTicks - 1);
      const toPlayer = {
        x: this.playerValue.x - enemy.x,
        y: this.playerValue.y - enemy.y,
      };
      const distance = Math.max(0.001, Math.hypot(toPlayer.x, toPlayer.y));
      const toward = { x: toPlayer.x / distance, y: toPlayer.y / distance };
      let velocity = toward;

      if (enemy.kind === "striker") {
        const orbitRadius = 245 + Math.min(60, this.waveValue * 4);
        const tangent = { x: -toward.y * enemy.orbitDirection, y: toward.x * enemy.orbitDirection };
        const radial = clamp((distance - orbitRadius) / 110, -1, 1);
        velocity = normalize(tangent.x * 0.78 + toward.x * radial, tangent.y * 0.78 + toward.y * radial);
      }

      const speedMultiplier = 1 + Math.min(0.38, (this.waveValue - 1) * 0.045);
      enemy.x += velocity.x * enemy.speed * speedMultiplier * SIMULATION_DT;
      enemy.y += velocity.y * enemy.speed * speedMultiplier * SIMULATION_DT;
    }
  }

  private resolveProjectileHits(): void {
    const spentProjectileIds = new Set<number>();
    for (const projectile of this.projectilesValue) {
      if (spentProjectileIds.has(projectile.id)) {
        continue;
      }
      const target = this.enemiesValue.find(
        (enemy) => !spentProjectileIds.has(projectile.id) && distanceSquared(projectile, enemy) <= (projectile.radius + enemy.radius) ** 2,
      );
      if (!target) {
        continue;
      }
      spentProjectileIds.add(projectile.id);
      this.damageEnemy(target.id, projectile.damage);
    }
    if (spentProjectileIds.size > 0) {
      this.projectilesValue = this.projectilesValue.filter((projectile) => !spentProjectileIds.has(projectile.id));
    }
  }

  private resolveEnemyContacts(): void {
    for (const enemy of this.enemiesValue) {
      if (enemy.contactCooldownTicks > 0 || this.playerValue.invulnerableTicks > 0) {
        continue;
      }
      if (distanceSquared(enemy, this.playerValue) > (enemy.radius + this.playerValue.radius) ** 2) {
        continue;
      }
      enemy.contactCooldownTicks = 45;
      const away = normalize(this.playerValue.x - enemy.x, this.playerValue.y - enemy.y);
      this.playerValue.x = clamp(this.playerValue.x + away.x * 22, ARENA_MARGIN + PLAYER_RADIUS, this.width - ARENA_MARGIN - PLAYER_RADIUS);
      this.playerValue.y = clamp(this.playerValue.y + away.y * 22, ARENA_MARGIN + PLAYER_RADIUS, this.height - ARENA_MARGIN - PLAYER_RADIUS);
      this.applyDamage(1);
    }
  }

  private advanceWaveIfClear(): void {
    if (this.enemiesValue.length > 0) {
      return;
    }
    if (this.waveDelayValue === 0) {
      this.waveDelayValue = WAVE_BREAK_TICKS;
      return;
    }
    this.waveDelayValue -= 1;
    if (this.waveDelayValue === 0) {
      this.waveValue += 1;
      this.spawnWave();
    }
  }

  private spawnWave(): void {
    const schedule: EnemyKind[] = ["chaser", "striker", "tank"];
    const count = Math.min(10, 2 + this.waveValue);
    for (let index = 0; index < count; index += 1) {
      const kind = this.waveValue === 1 ? schedule[index % schedule.length] : this.rng.pick(schedule);
      const definition = ENEMY_DEFINITIONS[kind];
      const preferredAngle = index === 0 && this.waveValue === 1 ? 0 : this.rng.range(0, Math.PI * 2);
      const { x, y } = this.findSpawnPosition(definition.radius, preferredAngle);
      const enemy: EnemyState = {
        ...definition,
        id: this.nextEnemyId,
        x,
        y,
        orbitDirection: this.rng.next() < 0.5 ? 1 : -1,
        contactCooldownTicks: 0,
      };
      this.nextEnemyId += 1;
      this.enemiesValue.push(enemy);
    }
    this.eventsValue.push({ type: "wave-start", x: this.playerValue.x, y: this.playerValue.y });
  }

  private findSpawnPosition(radius: number, preferredAngle: number): Vector2 {
    const minX = ARENA_MARGIN + radius;
    const maxX = this.width - ARENA_MARGIN - radius;
    const minY = ARENA_MARGIN + radius;
    const maxY = this.height - ARENA_MARGIN - radius;
    let angle = preferredAngle;

    for (let attempt = 0; attempt < 24; attempt += 1) {
      const distance = this.spawnRadius + 72 + this.rng.range(0, 100);
      const x = clamp(this.playerValue.x + Math.cos(angle) * distance, minX, maxX);
      const y = clamp(this.playerValue.y + Math.sin(angle) * distance, minY, maxY);
      if (distanceSquared({ x, y }, this.playerValue) >= this.spawnRadius ** 2) {
        return { x, y };
      }
      angle = this.rng.range(0, Math.PI * 2);
    }

    const candidates: Vector2[] = [
      { x: minX, y: minY },
      { x: minX, y: maxY },
      { x: maxX, y: minY },
      { x: maxX, y: maxY },
    ];
    return candidates.reduce((farthest, candidate) => (
      distanceSquared(candidate, this.playerValue) > distanceSquared(farthest, this.playerValue) ? candidate : farthest
    ));
  }

  private defeatEnemy(enemy: EnemyState): void {
    const index = this.enemiesValue.findIndex((candidate) => candidate.id === enemy.id);
    if (index < 0) {
      return;
    }
    this.enemiesValue.splice(index, 1);
    const points = ENEMY_SCORE[enemy.kind] * this.waveValue;
    this.scoreValue += points;
    this.enemiesDefeatedValue += 1;
    this.eventsValue.push({ type: "enemy-defeat", x: enemy.x, y: enemy.y, enemyKind: enemy.kind, score: points });
  }

  private finishGame(): void {
    if (this.phaseValue === "gameover") {
      return;
    }
    this.phaseValue = "gameover";
    this.completedGameValue = {
      seed: this.currentSeed,
      finalTick: this.tickValue,
      score: this.scoreValue,
      wave: this.waveValue,
    };
    this.completionRecords = [...this.completionRecords, { ...this.completedGameValue }];
    this.eventsValue.push({ type: "game-over", x: this.playerValue.x, y: this.playerValue.y });
  }
}

export const createNeutralInput = (): InputFrame => ({
  moveX: 0,
  moveY: 0,
  aimX: 641,
  aimY: 360,
  fire: false,
});
