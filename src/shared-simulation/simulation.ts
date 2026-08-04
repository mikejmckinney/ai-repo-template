export type EnemyKind = "chaser" | "tank" | "striker";

export type SimulationStatus = "ready" | "running" | "paused" | "gameover";

export interface InputFrame {
  up: boolean;
  down: boolean;
  left: boolean;
  right: boolean;
  fire: boolean;
  aimX: number;
  aimY: number;
}

export interface SimulationConfig {
  width: number;
  height: number;
  arenaPadding: number;
  fixedDelta: number;
  playerSpeed: number;
  playerRadius: number;
  playerMaxHealth: number;
  spawnRadius: number;
  spawnDistanceJitter: number;
  projectileSpeed: number;
  projectileLifeTicks: number;
  projectileRadius: number;
  projectileDamage: number;
  fireCooldownTicks: number;
  invulnerabilityTicks: number;
  initialWave: number;
}

export interface PlayerState {
  x: number;
  y: number;
  radius: number;
  health: number;
  maxHealth: number;
  invulnerableTicks: number;
  hitFlashTicks: number;
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
  score: number;
  phase: number;
  hitFlashTicks: number;
}

export interface ProjectileState {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  damage: number;
  lifeTicks: number;
}

export interface CompletionRecord {
  seed: number;
  finalTick: number;
  score: number;
  wave: number;
}

export interface SimulationState {
  status: SimulationStatus;
  seed: number;
  tick: number;
  score: number;
  wave: number;
  player: PlayerState;
  enemies: EnemyState[];
  projectiles: ProjectileState[];
  completionRecord: CompletionRecord | null;
}

export type SimulationEventType =
  | "shot"
  | "enemy-hit"
  | "enemy-defeated"
  | "player-hit"
  | "wave-started"
  | "game-over";

export interface SimulationEvent {
  type: SimulationEventType;
  x: number;
  y: number;
  enemyId?: number;
  enemyKind?: EnemyKind;
  score?: number;
}

export interface StepResult {
  events: SimulationEvent[];
}

const DEFAULT_SEED = 0x51e697e;

const DEFAULT_CONFIG: SimulationConfig = {
  width: 1280,
  height: 720,
  arenaPadding: 44,
  fixedDelta: 1 / 60,
  playerSpeed: 285,
  playerRadius: 23,
  playerMaxHealth: 3,
  spawnRadius: 260,
  spawnDistanceJitter: 72,
  projectileSpeed: 720,
  projectileLifeTicks: 90,
  projectileRadius: 5,
  projectileDamage: 1,
  fireCooldownTicks: 7,
  invulnerabilityTicks: 78,
  initialWave: 1,
};

const ENEMY_STATS: Record<
  EnemyKind,
  { radius: number; speed: number; health: number; score: number }
> = {
  chaser: { radius: 23, speed: 92, health: 1, score: 100 },
  tank: { radius: 30, speed: 46, health: 4, score: 260 },
  striker: { radius: 21, speed: 72, health: 2, score: 175 },
};

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function distanceSquared(ax: number, ay: number, bx: number, by: number): number {
  const dx = ax - bx;
  const dy = ay - by;
  return dx * dx + dy * dy;
}

function normalizeSeed(seed: number): number {
  if (!Number.isFinite(seed)) {
    return DEFAULT_SEED;
  }

  return seed >>> 0;
}

class SeededRandom {
  private state: number;

  public constructor(seed: number) {
    this.state = normalizeSeed(seed);
  }

  public next(): number {
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let value = this.state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  }

  public range(minimum: number, maximum: number): number {
    return minimum + (maximum - minimum) * this.next();
  }
}

function createInitialState(config: SimulationConfig, seed: number): SimulationState {
  return {
    status: "ready",
    seed,
    tick: 0,
    score: 0,
    wave: config.initialWave,
    player: {
      x: config.width / 2,
      y: config.height / 2,
      radius: config.playerRadius,
      health: config.playerMaxHealth,
      maxHealth: config.playerMaxHealth,
      invulnerableTicks: 0,
      hitFlashTicks: 0,
    },
    enemies: [],
    projectiles: [],
    completionRecord: null,
  };
}

export class VectorSiegeSimulation {
  public readonly config: SimulationConfig;

  public state: SimulationState;

  public lastEvents: SimulationEvent[] = [];

  private random: SeededRandom;

  private nextEntityId = 1;

  private fireCooldownTicks = 0;

  private readonly completionRecords: CompletionRecord[] = [];

  public constructor(seed = DEFAULT_SEED, config: Partial<SimulationConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    const normalizedSeed = normalizeSeed(seed);
    this.state = createInitialState(this.config, normalizedSeed);
    this.random = new SeededRandom(normalizedSeed);
  }

  public start(): void {
    this.state = createInitialState(this.config, this.state.seed);
    this.random = new SeededRandom(this.state.seed);
    this.nextEntityId = 1;
    this.fireCooldownTicks = 0;
    this.lastEvents = [];
    this.state.status = "running";
    this.spawnWave(this.state.wave, []);
  }

  public pause(): void {
    if (this.state.status === "running") {
      this.state.status = "paused";
    }
  }

  public resume(): void {
    if (this.state.status === "paused") {
      this.state.status = "running";
    }
  }

  public restart(): void {
    this.start();
  }

  public clearEnemies(): void {
    this.state.enemies = [];
    this.state.projectiles = [];
  }

  public addEnemy(kind: EnemyKind, x: number, y: number): EnemyState {
    const enemy = this.createEnemy(kind, x, y);
    this.state.enemies.push(enemy);
    return enemy;
  }

  public get completionHistory(): CompletionRecord[] {
    return this.completionRecords.map((record) => ({ ...record }));
  }

  public step(input: InputFrame): StepResult {
    this.lastEvents = [];

    if (this.state.status !== "running") {
      return { events: [] };
    }

    this.state.tick += 1;
    this.decrementTimers();
    this.movePlayer(input);
    this.tryShoot(input);
    this.moveEnemies();
    this.moveProjectiles();

    if (this.state.status === "running" && this.state.enemies.length === 0) {
      this.state.wave += 1;
      this.spawnWave(this.state.wave, this.lastEvents);
    }

    return { events: [...this.lastEvents] };
  }

  public snapshot(): SimulationState {
    return {
      status: this.state.status,
      seed: this.state.seed,
      tick: this.state.tick,
      score: this.state.score,
      wave: this.state.wave,
      player: { ...this.state.player },
      enemies: this.state.enemies.map((enemy) => ({ ...enemy })),
      projectiles: this.state.projectiles.map((projectile) => ({ ...projectile })),
      completionRecord: this.state.completionRecord ? { ...this.state.completionRecord } : null,
    };
  }

  private decrementTimers(): void {
    this.fireCooldownTicks = Math.max(0, this.fireCooldownTicks - 1);
    this.state.player.invulnerableTicks = Math.max(0, this.state.player.invulnerableTicks - 1);
    this.state.player.hitFlashTicks = Math.max(0, this.state.player.hitFlashTicks - 1);

    for (const enemy of this.state.enemies) {
      enemy.hitFlashTicks = Math.max(0, enemy.hitFlashTicks - 1);
    }
  }

  private movePlayer(input: InputFrame): void {
    let x = Number(input.right) - Number(input.left);
    let y = Number(input.down) - Number(input.up);
    const length = Math.hypot(x, y);

    if (length > 0) {
      x /= length;
      y /= length;
    }

    const distance = this.config.playerSpeed * this.config.fixedDelta;
    const minimumX = this.config.arenaPadding + this.state.player.radius;
    const maximumX = this.config.width - this.config.arenaPadding - this.state.player.radius;
    const minimumY = this.config.arenaPadding + this.state.player.radius;
    const maximumY = this.config.height - this.config.arenaPadding - this.state.player.radius;

    this.state.player.x = clamp(this.state.player.x + x * distance, minimumX, maximumX);
    this.state.player.y = clamp(this.state.player.y + y * distance, minimumY, maximumY);
  }

  private tryShoot(input: InputFrame): void {
    if (!input.fire || this.fireCooldownTicks > 0) {
      return;
    }

    const aimX = Number.isFinite(input.aimX) ? input.aimX : this.state.player.x + 1;
    const aimY = Number.isFinite(input.aimY) ? input.aimY : this.state.player.y;
    let directionX = aimX - this.state.player.x;
    let directionY = aimY - this.state.player.y;
    const length = Math.hypot(directionX, directionY) || 1;
    directionX /= length;
    directionY /= length;

    const muzzleDistance = this.state.player.radius + 9;
    this.state.projectiles.push({
      id: this.nextEntityId++,
      x: this.state.player.x + directionX * muzzleDistance,
      y: this.state.player.y + directionY * muzzleDistance,
      vx: directionX * this.config.projectileSpeed * this.config.fixedDelta,
      vy: directionY * this.config.projectileSpeed * this.config.fixedDelta,
      radius: this.config.projectileRadius,
      damage: this.config.projectileDamage,
      lifeTicks: this.config.projectileLifeTicks,
    });
    this.fireCooldownTicks = this.config.fireCooldownTicks;
    this.lastEvents.push({ type: "shot", x: this.state.player.x, y: this.state.player.y });
  }

  private moveEnemies(): void {
    for (const enemy of this.state.enemies) {
      const dx = this.state.player.x - enemy.x;
      const dy = this.state.player.y - enemy.y;
      const length = Math.hypot(dx, dy) || 1;
      const directX = dx / length;
      const directY = dy / length;
      let moveX = directX;
      let moveY = directY;

      if (enemy.kind === "striker") {
        const tangentX = -directY;
        const tangentY = directX;
        const orbit = Math.sin(enemy.phase + this.state.tick * 0.08) * 0.72;
        moveX = directX * 0.76 + tangentX * orbit;
        moveY = directY * 0.76 + tangentY * orbit;
        const moveLength = Math.hypot(moveX, moveY) || 1;
        moveX /= moveLength;
        moveY /= moveLength;
      }

      const distance = enemy.speed * (1 + Math.min(0.42, (this.state.wave - 1) * 0.035)) * this.config.fixedDelta;
      enemy.x = clamp(
        enemy.x + moveX * distance,
        this.config.arenaPadding + enemy.radius,
        this.config.width - this.config.arenaPadding - enemy.radius,
      );
      enemy.y = clamp(
        enemy.y + moveY * distance,
        this.config.arenaPadding + enemy.radius,
        this.config.height - this.config.arenaPadding - enemy.radius,
      );

      const contactDistance = enemy.radius + this.state.player.radius;
      if (distanceSquared(enemy.x, enemy.y, this.state.player.x, this.state.player.y) <= contactDistance * contactDistance) {
        this.damagePlayer(1, enemy);
      }
    }
  }

  private moveProjectiles(): void {
    const remainingProjectiles: ProjectileState[] = [];

    for (const projectile of this.state.projectiles) {
      projectile.x += projectile.vx;
      projectile.y += projectile.vy;
      projectile.lifeTicks -= 1;

      const insideArena =
        projectile.x >= this.config.arenaPadding &&
        projectile.x <= this.config.width - this.config.arenaPadding &&
        projectile.y >= this.config.arenaPadding &&
        projectile.y <= this.config.height - this.config.arenaPadding;

      if (!insideArena || projectile.lifeTicks <= 0) {
        continue;
      }

      const enemyIndex = this.state.enemies.findIndex((enemy) => {
        const collisionDistance = projectile.radius + enemy.radius;
        return distanceSquared(projectile.x, projectile.y, enemy.x, enemy.y) <= collisionDistance * collisionDistance;
      });

      if (enemyIndex < 0) {
        remainingProjectiles.push(projectile);
        continue;
      }

      const enemy = this.state.enemies[enemyIndex];
      enemy.health -= projectile.damage;
      enemy.hitFlashTicks = 6;
      this.lastEvents.push({
        type: "enemy-hit",
        x: enemy.x,
        y: enemy.y,
        enemyId: enemy.id,
        enemyKind: enemy.kind,
      });

      if (enemy.health <= 0) {
        this.state.enemies.splice(enemyIndex, 1);
        this.state.score += enemy.score;
        this.lastEvents.push({
          type: "enemy-defeated",
          x: enemy.x,
          y: enemy.y,
          enemyId: enemy.id,
          enemyKind: enemy.kind,
          score: enemy.score,
        });
      }
    }

    this.state.projectiles = remainingProjectiles;
  }

  private damagePlayer(amount: number, enemy: EnemyState): void {
    if (this.state.player.invulnerableTicks > 0 || this.state.status !== "running") {
      return;
    }

    this.state.player.health = Math.max(0, this.state.player.health - amount);
    this.state.player.invulnerableTicks = this.config.invulnerabilityTicks;
    this.state.player.hitFlashTicks = 12;
    this.lastEvents.push({
      type: "player-hit",
      x: this.state.player.x,
      y: this.state.player.y,
      enemyId: enemy.id,
      enemyKind: enemy.kind,
    });

    if (this.state.player.health <= 0) {
      this.finishRun();
    }
  }

  private finishRun(): void {
    this.state.status = "gameover";
    const record: CompletionRecord = {
      seed: this.state.seed,
      finalTick: this.state.tick,
      score: this.state.score,
      wave: this.state.wave,
    };
    this.state.completionRecord = record;
    this.completionRecords.push({ ...record });
    this.lastEvents.push({
      type: "game-over",
      x: this.state.player.x,
      y: this.state.player.y,
    });
  }

  private spawnWave(wave: number, events: SimulationEvent[]): void {
    const count = Math.min(16, 4 + wave);

    for (let index = 0; index < count; index += 1) {
      const kind = this.kindForWave(wave, index);
      const position = this.spawnPoint(kind);
      this.state.enemies.push(this.createEnemy(kind, position.x, position.y));
    }

    events.push({ type: "wave-started", x: this.state.player.x, y: this.state.player.y });
  }

  private kindForWave(wave: number, index: number): EnemyKind {
    if (index === 0 || index % 3 === 0) {
      return "chaser";
    }

    if (wave >= 2 && index % 4 === 0) {
      return "striker";
    }

    return "tank";
  }

  private spawnPoint(kind: EnemyKind): { x: number; y: number } {
    const radius = ENEMY_STATS[kind].radius;
    const minimumX = this.config.arenaPadding + radius;
    const maximumX = this.config.width - this.config.arenaPadding - radius;
    const minimumY = this.config.arenaPadding + radius;
    const maximumY = this.config.height - this.config.arenaPadding - radius;

    for (let attempt = 0; attempt < 32; attempt += 1) {
      const angle = this.random.range(0, Math.PI * 2);
      const distance = this.config.spawnRadius + this.random.range(0, this.config.spawnDistanceJitter);
      const x = this.state.player.x + Math.cos(angle) * distance;
      const y = this.state.player.y + Math.sin(angle) * distance;
      const farEnough = distanceSquared(x, y, this.state.player.x, this.state.player.y) >= this.config.spawnRadius ** 2;

      if (x >= minimumX && x <= maximumX && y >= minimumY && y <= maximumY && farEnough) {
        return { x, y };
      }
    }

    const fallbackCandidates = [
      { x: minimumX, y: minimumY },
      { x: maximumX, y: minimumY },
      { x: minimumX, y: maximumY },
      { x: maximumX, y: maximumY },
      { x: minimumX, y: (minimumY + maximumY) / 2 },
      { x: maximumX, y: (minimumY + maximumY) / 2 },
      { x: (minimumX + maximumX) / 2, y: minimumY },
      { x: (minimumX + maximumX) / 2, y: maximumY },
    ];
    fallbackCandidates.sort(
      (left, right) =>
        distanceSquared(right.x, right.y, this.state.player.x, this.state.player.y) -
        distanceSquared(left.x, left.y, this.state.player.x, this.state.player.y),
    );
    return fallbackCandidates[0];
  }

  private createEnemy(kind: EnemyKind, x: number, y: number): EnemyState {
    const base = ENEMY_STATS[kind];
    const waveHealthBonus = Math.floor((this.state.wave - 1) / (kind === "tank" ? 2 : 4));
    const health = base.health + waveHealthBonus;

    return {
      id: this.nextEntityId++,
      kind,
      x,
      y,
      radius: base.radius,
      health,
      maxHealth: health,
      speed: base.speed,
      score: base.score + (this.state.wave - 1) * 12,
      phase: this.random.range(0, Math.PI * 2),
      hitFlashTicks: 0,
    };
  }
}

export { DEFAULT_CONFIG };
