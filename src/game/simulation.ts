export const ARENA_WIDTH = 1280;
export const ARENA_HEIGHT = 720;
export const ARENA_MARGIN = 54;
export const FIXED_STEP_MS = 1000 / 60;
export const PLAYER_RADIUS = 22;

export type GameStatus = "menu" | "running" | "paused" | "gameover";
export type EnemyKind = "chaser" | "striker" | "tank";

export interface Vector2 {
  x: number;
  y: number;
}

export interface InputFrame {
  up?: boolean;
  down?: boolean;
  left?: boolean;
  right?: boolean;
  fire?: boolean;
  aimX?: number;
  aimY?: number;
}

export interface PlayerState extends Vector2 {
  health: number;
  maxHealth: number;
  invulnerableUntilTick: number;
}

export interface EnemyState extends Vector2 {
  id: number;
  kind: EnemyKind;
  health: number;
  maxHealth: number;
  radius: number;
  speed: number;
  phase: number;
}

export interface ProjectileState extends Vector2 {
  id: number;
  velocityX: number;
  velocityY: number;
  radius: number;
  remainingTicks: number;
}

export type SimulationEvent =
  | { type: "shot"; x: number; y: number; angle: number }
  | { type: "enemyHit"; x: number; y: number; kind: EnemyKind }
  | { type: "enemyDefeated"; x: number; y: number; kind: EnemyKind; score: number }
  | { type: "playerHit"; x: number; y: number; health: number }
  | { type: "waveStarted"; wave: number; count: number }
  | { type: "waveCleared"; wave: number }
  | { type: "gameOver"; finalTick: number; score: number; wave: number };

export interface CompletedGame {
  seed: number;
  finalTick: number;
  score: number;
  wave: number;
}

export interface SimulationSnapshot {
  status: GameStatus;
  seed: number;
  tick: number;
  score: number;
  wave: number;
  player: PlayerState;
  enemies: EnemyState[];
  projectiles: ProjectileState[];
  completedGame: CompletedGame | null;
}

interface SimulationConfig {
  seed?: number;
  spawnRadius?: number;
}

const DEFAULT_SEED = 20260805;
const DEFAULT_SPAWN_RADIUS = 270;
const PLAYER_SPEED = 250;
const FIRE_COOLDOWN_TICKS = 9;
const PROJECTILE_SPEED = 900;
const PROJECTILE_LIFETIME_TICKS = 70;
const INVULNERABILITY_TICKS = 75;
const WAVE_INTERMISSION_TICKS = 52;
const STARTING_HEALTH = 5;
const WAVE_SIZE_BASE = 4;

const ENEMY_STATS: Record<EnemyKind, Omit<EnemyState, "id" | "x" | "y" | "phase">> = {
  chaser: { kind: "chaser", health: 1, maxHealth: 1, radius: 23, speed: 76 },
  striker: { kind: "striker", health: 2, maxHealth: 2, radius: 20, speed: 110 },
  tank: { kind: "tank", health: 4, maxHealth: 4, radius: 30, speed: 43 },
};

const EMPTY_INPUT: Required<InputFrame> = {
  up: false,
  down: false,
  left: false,
  right: false,
  fire: false,
  aimX: ARENA_WIDTH / 2,
  aimY: ARENA_HEIGHT / 2,
};

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function distanceSquared(a: Vector2, b: Vector2): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return dx * dx + dy * dy;
}

function normalise(x: number, y: number): Vector2 {
  const length = Math.hypot(x, y);
  if (length === 0) {
    return { x: 0, y: 0 };
  }
  return { x: x / length, y: y / length };
}

class SeededRandom {
  private state: number;

  public constructor(seed: number) {
    this.state = (seed >>> 0) || 1;
  }

  public reset(seed: number): void {
    this.state = (seed >>> 0) || 1;
  }

  public next(): number {
    this.state = (this.state + 0x6d2b79f5) | 0;
    let value = Math.imul(this.state ^ (this.state >>> 15), 1 | this.state);
    value ^= value + Math.imul(value ^ (value >>> 7), 61 | value);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  }
}

export class ArenaSimulation {
  public readonly spawnRadius: number;

  private random: SeededRandom;
  private readonly events: SimulationEvent[] = [];
  private readonly player: PlayerState = {
    x: ARENA_WIDTH / 2,
    y: ARENA_HEIGHT / 2,
    health: STARTING_HEALTH,
    maxHealth: STARTING_HEALTH,
    invulnerableUntilTick: 0,
  };
  private enemies: EnemyState[] = [];
  private projectiles: ProjectileState[] = [];
  private nextEnemyId = 1;
  private nextProjectileId = 1;
  private fireCooldownTicks = 0;
  private waveIntermissionTicks = 0;
  private currentSeed: number;
  private gameStatus: GameStatus = "menu";
  private currentTick = 0;
  private currentScore = 0;
  private currentWave = 0;
  private completed: CompletedGame | null = null;

  public constructor(config: SimulationConfig = {}) {
    this.currentSeed = normaliseSeed(config.seed ?? DEFAULT_SEED);
    this.spawnRadius = config.spawnRadius ?? DEFAULT_SPAWN_RADIUS;
    this.random = new SeededRandom(this.currentSeed);
  }

  public start(seed = this.currentSeed): void {
    this.currentSeed = normaliseSeed(seed);
    this.random.reset(this.currentSeed);
    this.currentTick = 0;
    this.currentScore = 0;
    this.currentWave = 1;
    this.gameStatus = "running";
    this.completed = null;
    this.fireCooldownTicks = 0;
    this.waveIntermissionTicks = 0;
    this.nextEnemyId = 1;
    this.nextProjectileId = 1;
    this.player.x = ARENA_WIDTH / 2;
    this.player.y = ARENA_HEIGHT / 2;
    this.player.health = this.player.maxHealth;
    this.player.invulnerableUntilTick = 0;
    this.enemies = [];
    this.projectiles = [];
    this.events.length = 0;
    this.spawnWave();
  }

  public pause(): void {
    if (this.gameStatus === "running") {
      this.gameStatus = "paused";
    }
  }

  public resume(): void {
    if (this.gameStatus === "paused") {
      this.gameStatus = "running";
    }
  }

  public togglePause(): void {
    if (this.gameStatus === "running") {
      this.pause();
    } else if (this.gameStatus === "paused") {
      this.resume();
    }
  }

  public step(input: InputFrame = EMPTY_INPUT): void {
    if (this.gameStatus !== "running") {
      return;
    }

    const frame: Required<InputFrame> = { ...EMPTY_INPUT, ...input };
    this.currentTick += 1;
    this.updatePlayer(frame);
    this.updateProjectiles();
    this.updateEnemies();
    this.resolveContacts();
    this.updateWaveState();

    if (this.fireCooldownTicks > 0) {
      this.fireCooldownTicks -= 1;
    }
    if (frame.fire && this.fireCooldownTicks <= 0) {
      this.fire(frame.aimX, frame.aimY);
    }
  }

  public drainEvents(): SimulationEvent[] {
    return this.events.splice(0, this.events.length);
  }

  public getSnapshot(): SimulationSnapshot {
    return {
      status: this.gameStatus,
      seed: this.currentSeed,
      tick: this.currentTick,
      score: this.currentScore,
      wave: this.currentWave,
      player: { ...this.player },
      enemies: this.enemies.map((enemy) => ({ ...enemy })),
      projectiles: this.projectiles.map((projectile) => ({ ...projectile })),
      completedGame: this.completed ? { ...this.completed } : null,
    };
  }

  public get status(): GameStatus {
    return this.gameStatus;
  }

  private updatePlayer(input: Required<InputFrame>): void {
    const horizontal = Number(input.right) - Number(input.left);
    const vertical = Number(input.down) - Number(input.up);
    const direction = normalise(horizontal, vertical);
    this.player.x = clamp(
      this.player.x + direction.x * PLAYER_SPEED * (FIXED_STEP_MS / 1000),
      ARENA_MARGIN + PLAYER_RADIUS,
      ARENA_WIDTH - ARENA_MARGIN - PLAYER_RADIUS,
    );
    this.player.y = clamp(
      this.player.y + direction.y * PLAYER_SPEED * (FIXED_STEP_MS / 1000),
      ARENA_MARGIN + PLAYER_RADIUS,
      ARENA_HEIGHT - ARENA_MARGIN - PLAYER_RADIUS,
    );
  }

  private updateProjectiles(): void {
    this.projectiles = this.projectiles.filter((projectile) => {
      projectile.x += projectile.velocityX * (FIXED_STEP_MS / 1000);
      projectile.y += projectile.velocityY * (FIXED_STEP_MS / 1000);
      projectile.remainingTicks -= 1;
      return (
        projectile.remainingTicks > 0 &&
        projectile.x >= ARENA_MARGIN &&
        projectile.x <= ARENA_WIDTH - ARENA_MARGIN &&
        projectile.y >= ARENA_MARGIN &&
        projectile.y <= ARENA_HEIGHT - ARENA_MARGIN
      );
    });
  }

  private updateEnemies(): void {
    for (const enemy of this.enemies) {
      const toPlayer = normalise(this.player.x - enemy.x, this.player.y - enemy.y);
      let velocity = toPlayer;
      if (enemy.kind === "striker") {
        const strafe = Math.sin((this.currentTick + enemy.phase) * 0.13) * 0.62;
        velocity = normalise(toPlayer.x - toPlayer.y * strafe, toPlayer.y + toPlayer.x * strafe);
      }
      const step = enemy.speed * (FIXED_STEP_MS / 1000);
      enemy.x = clamp(enemy.x + velocity.x * step, ARENA_MARGIN + enemy.radius, ARENA_WIDTH - ARENA_MARGIN - enemy.radius);
      enemy.y = clamp(enemy.y + velocity.y * step, ARENA_MARGIN + enemy.radius, ARENA_HEIGHT - ARENA_MARGIN - enemy.radius);
    }
  }

  private resolveContacts(): void {
    const survivingProjectiles: ProjectileState[] = [];
    for (const projectile of this.projectiles) {
      const enemy = this.enemies.find((candidate) => distanceSquared(projectile, candidate) <= (projectile.radius + candidate.radius) ** 2);
      if (!enemy) {
        survivingProjectiles.push(projectile);
        continue;
      }

      enemy.health -= 1;
      this.events.push({ type: "enemyHit", x: enemy.x, y: enemy.y, kind: enemy.kind });
      if (enemy.health <= 0) {
        const defeatScore = this.scoreFor(enemy.kind);
        this.currentScore += defeatScore;
        this.events.push({ type: "enemyDefeated", x: enemy.x, y: enemy.y, kind: enemy.kind, score: defeatScore });
        this.enemies = this.enemies.filter((candidate) => candidate.id !== enemy.id);
      }
    }
    this.projectiles = survivingProjectiles;

    if (this.currentTick >= this.player.invulnerableUntilTick) {
      const enemy = this.enemies.find((candidate) => distanceSquared(this.player, candidate) <= (PLAYER_RADIUS + candidate.radius) ** 2);
      if (enemy) {
        this.player.health = Math.max(0, this.player.health - 1);
        this.player.invulnerableUntilTick = this.currentTick + INVULNERABILITY_TICKS;
        this.events.push({ type: "playerHit", x: this.player.x, y: this.player.y, health: this.player.health });
        const away = normalise(enemy.x - this.player.x, enemy.y - this.player.y);
        enemy.x = clamp(enemy.x + away.x * 28, ARENA_MARGIN + enemy.radius, ARENA_WIDTH - ARENA_MARGIN - enemy.radius);
        enemy.y = clamp(enemy.y + away.y * 28, ARENA_MARGIN + enemy.radius, ARENA_HEIGHT - ARENA_MARGIN - enemy.radius);
        if (this.player.health === 0) {
          this.finishGame();
        }
      }
    }
  }

  private updateWaveState(): void {
    if (this.gameStatus !== "running") {
      return;
    }
    if (this.enemies.length > 0) {
      return;
    }
    if (this.waveIntermissionTicks === 0) {
      this.waveIntermissionTicks = WAVE_INTERMISSION_TICKS;
      this.events.push({ type: "waveCleared", wave: this.currentWave });
      return;
    }
    this.waveIntermissionTicks -= 1;
    if (this.waveIntermissionTicks === 0) {
      this.currentWave += 1;
      this.spawnWave();
    }
  }

  private spawnWave(): void {
    const count = Math.min(14, WAVE_SIZE_BASE + this.currentWave);
    for (let index = 0; index < count; index += 1) {
      const kinds: EnemyKind[] = ["chaser", "striker", "chaser", "tank", "striker"];
      const kind = kinds[(index + this.currentWave - 1) % kinds.length];
      this.spawnEnemy(kind, index, count);
    }
    this.events.push({ type: "waveStarted", wave: this.currentWave, count });
  }

  private spawnEnemy(kind: EnemyKind, index: number, total: number): void {
    const stats = ENEMY_STATS[kind];
    let x = this.player.x;
    let y = this.player.y;
    const minimumDistanceSquared = this.spawnRadius ** 2;
    for (let attempt = 0; attempt < 12; attempt += 1) {
      const angle = (index / total) * Math.PI * 2 + (this.random.next() - 0.5) * 0.16 + attempt * 0.37;
      const distance = this.spawnRadius + this.random.next() * 92;
      x = clamp(this.player.x + Math.cos(angle) * distance, ARENA_MARGIN + stats.radius, ARENA_WIDTH - ARENA_MARGIN - stats.radius);
      y = clamp(this.player.y + Math.sin(angle) * distance, ARENA_MARGIN + stats.radius, ARENA_HEIGHT - ARENA_MARGIN - stats.radius);
      if (distanceSquared({ x, y }, this.player) >= minimumDistanceSquared) {
        break;
      }
    }
    const difficultyMultiplier = 1 + Math.min(0.55, (this.currentWave - 1) * 0.045);
    this.enemies.push({
      ...stats,
      speed: stats.speed * difficultyMultiplier,
      id: this.nextEnemyId,
      x,
      y,
      phase: Math.floor(this.random.next() * 360),
    });
    this.nextEnemyId += 1;
  }

  private fire(aimX: number, aimY: number): void {
    const direction = normalise(aimX - this.player.x, aimY - this.player.y);
    const safeDirection = direction.x === 0 && direction.y === 0 ? { x: 1, y: 0 } : direction;
    this.projectiles.push({
      id: this.nextProjectileId,
      x: this.player.x + safeDirection.x * (PLAYER_RADIUS + 8),
      y: this.player.y + safeDirection.y * (PLAYER_RADIUS + 8),
      velocityX: safeDirection.x * PROJECTILE_SPEED,
      velocityY: safeDirection.y * PROJECTILE_SPEED,
      radius: 8,
      remainingTicks: PROJECTILE_LIFETIME_TICKS,
    });
    this.nextProjectileId += 1;
    this.fireCooldownTicks = FIRE_COOLDOWN_TICKS;
    this.events.push({ type: "shot", x: this.player.x, y: this.player.y, angle: Math.atan2(safeDirection.y, safeDirection.x) });
  }

  private scoreFor(kind: EnemyKind): number {
    const baseScore: Record<EnemyKind, number> = { chaser: 100, striker: 150, tank: 250 };
    return baseScore[kind] + this.currentWave * 25;
  }

  private finishGame(): void {
    this.gameStatus = "gameover";
    this.completed = { seed: this.currentSeed, finalTick: this.currentTick, score: this.currentScore, wave: this.currentWave };
    this.events.push({ type: "gameOver", finalTick: this.currentTick, score: this.currentScore, wave: this.currentWave });
  }
}

function normaliseSeed(seed: number): number {
  const integerSeed = Math.floor(seed) >>> 0;
  return integerSeed || DEFAULT_SEED;
}
