import type {
  ArenaBounds,
  CompletedGameRecord,
  EnemyKind,
  EnemyState,
  GamePhase,
  PlayerState,
  ProjectileState,
  Seed,
  SimulationConfig,
  SimulationController,
  SimulationEvent,
  SimulationSnapshot,
  StepInput,
} from "./types";

type SimulationOptions = SimulationConfig & {
  spawnRadius?: number;
};

const DEFAULT_WIDTH = 1280;
const DEFAULT_HEIGHT = 720;
const DEFAULT_SEED = "vector-siege-stage-1";
const DEFAULT_PLAYER_HEALTH = 5;
const PLAYER_RADIUS = 16;
const PLAYER_SPEED = 5;
const PLAYER_INVULNERABILITY_TICKS = 45;
const PLAYER_HIT_FLASH_TICKS = 8;
const PROJECTILE_RADIUS = 4;
const PROJECTILE_SPEED = 13;
const PROJECTILE_DAMAGE = 1;
const PROJECTILE_LIFETIME_TICKS = 90;
const FIRE_COOLDOWN_TICKS = 8;
const TWO_PI = Math.PI * 2;

const ENEMY_KINDS: EnemyKind[] = ["chaser", "striker", "tank"];

interface EnemyStats {
  radius: number;
  health: number;
  speed: number;
  contactDamage: number;
  score: number;
}

class DeterministicRandom {
  private state: number;

  public constructor(seed: string) {
    this.state = hashSeed(seed) || 0x9e3779b9;
  }

  public next(): number {
    let value = this.state;
    value ^= value << 13;
    value ^= value >>> 17;
    value ^= value << 5;
    this.state = value >>> 0;
    return this.state / 0x100000000;
  }
}

function hashSeed(seed: string): number {
  let hash = 0x811c9dc5;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

function canonicalSeed(seed: Seed | undefined): string {
  if (seed === undefined) {
    return DEFAULT_SEED;
  }
  if (typeof seed === "number" && !Number.isFinite(seed)) {
    throw new RangeError("Simulation seeds must be finite numbers or strings");
  }
  return String(seed);
}

function finiteOr(value: number | undefined, fallback: number): number {
  return value !== undefined && Number.isFinite(value) ? value : fallback;
}

function clamp(value: number, minimum: number, maximum: number): number {
  if (minimum > maximum) {
    return (minimum + maximum) / 2;
  }
  return Math.max(minimum, Math.min(maximum, value));
}

function distanceSquared(firstX: number, firstY: number, secondX: number, secondY: number): number {
  const deltaX = firstX - secondX;
  const deltaY = firstY - secondY;
  return deltaX * deltaX + deltaY * deltaY;
}

function normalize(x: number, y: number): { x: number; y: number } {
  const length = Math.hypot(x, y);
  if (length === 0) {
    return { x: 1, y: 0 };
  }
  return { x: x / length, y: y / length };
}

function copyArena(arena: ArenaBounds): ArenaBounds {
  return { left: arena.left, top: arena.top, right: arena.right, bottom: arena.bottom };
}

function createArena(config: SimulationConfig): ArenaBounds {
  if (config.arena !== undefined) {
    const arena = copyArena(config.arena);
    if (
      !Number.isFinite(arena.left) ||
      !Number.isFinite(arena.top) ||
      !Number.isFinite(arena.right) ||
      !Number.isFinite(arena.bottom) ||
      arena.right <= arena.left ||
      arena.bottom <= arena.top
    ) {
      throw new RangeError("Simulation arena must have finite increasing bounds");
    }
    return arena;
  }

  const width = finiteOr(config.width, DEFAULT_WIDTH);
  const height = finiteOr(config.height, DEFAULT_HEIGHT);
  if (width <= 0 || height <= 0) {
    throw new RangeError("Simulation dimensions must be positive");
  }
  return { left: 0, top: 0, right: width, bottom: height };
}

function getEnemyStats(kind: EnemyKind, wave: number): EnemyStats {
  const difficulty = wave - 1;
  if (kind === "tank") {
    return {
      radius: 24,
      health: 3 + Math.floor(difficulty / 2),
      speed: 0.65 + difficulty * 0.03,
      contactDamage: 2,
      score: 300,
    };
  }
  if (kind === "striker") {
    return {
      radius: 12,
      health: 1 + Math.floor(difficulty / 3),
      speed: 1.45 + difficulty * 0.05,
      contactDamage: 1,
      score: 150,
    };
  }
  return {
    radius: 17,
    health: 1 + Math.floor(difficulty / 3),
    speed: 1.05 + difficulty * 0.04,
    contactDamage: 1,
    score: 100,
  };
}

export class Simulation implements SimulationController {
  private readonly arena: ArenaBounds;

  private readonly playerRadius: number;

  private readonly playerMaxHealth: number;

  private readonly spawnRadius: number;

  private phase: GamePhase = "menu";

  private seed: string;

  private random: DeterministicRandom;

  private tick = 0;

  private score = 0;

  private wave = 0;

  private player: PlayerState;

  private projectiles: ProjectileState[] = [];

  private enemies: EnemyState[] = [];

  private completedGame: CompletedGameRecord | null = null;

  private events: SimulationEvent[] = [];

  private nextProjectileId = 1;

  private nextEnemyId = 1;

  private fireCooldownTicks = 0;

  public constructor(config: SimulationOptions = {}) {
    this.arena = createArena(config);
    this.playerRadius = Math.max(
      1,
      Math.min(PLAYER_RADIUS, (this.arena.right - this.arena.left) / 2, (this.arena.bottom - this.arena.top) / 2),
    );
    this.playerMaxHealth = Math.max(1, Math.floor(finiteOr(config.playerHealth, DEFAULT_PLAYER_HEALTH)));
    const defaultSpawnRadius = Math.min(
      280,
      Math.min(this.arena.right - this.arena.left, this.arena.bottom - this.arena.top) * 0.4,
    );
    this.spawnRadius = Math.max(0, finiteOr(config.spawnRadius, defaultSpawnRadius));
    this.seed = canonicalSeed(config.seed);
    this.random = new DeterministicRandom(this.seed);
    this.player = this.createPlayer();
  }

  public start(): void {
    if (this.phase !== "menu") {
      return;
    }
    this.beginRun(this.seed);
  }

  public pause(): void {
    if (this.phase === "running") {
      this.phase = "paused";
    }
  }

  public resume(): void {
    if (this.phase === "paused") {
      this.phase = "running";
    }
  }

  public restart(seed?: Seed): void {
    this.beginRun(canonicalSeed(seed ?? this.seed));
  }

  public step(input: StepInput): void {
    if (this.phase !== "running") {
      return;
    }

    this.tick += 1;
    this.decrementTransientTimers();
    this.movePlayer(input);
    this.decrementFireCooldown();
    this.fireProjectile(input);
    this.moveProjectilesAndResolveHits();
    this.moveEnemies();
    this.resolveContactDamage();

    if (this.phase === "running" && this.enemies.length === 0) {
      this.startNextWave();
    }
  }

  public snapshot(): SimulationSnapshot {
    return {
      phase: this.phase,
      seed: this.seed,
      tick: this.tick,
      score: this.score,
      wave: this.wave,
      arena: copyArena(this.arena),
      player: { ...this.player },
      projectiles: this.projectiles.map((projectile) => ({ ...projectile })),
      enemies: this.enemies.map((enemy) => ({ ...enemy })),
      completedGame: this.completedGame === null ? null : { ...this.completedGame },
    };
  }

  public drainEvents(): SimulationEvent[] {
    const pending = this.events;
    this.events = [];
    return pending;
  }

  private beginRun(seed: string): void {
    this.seed = seed;
    this.random = new DeterministicRandom(seed);
    this.phase = "running";
    this.tick = 0;
    this.score = 0;
    this.wave = 0;
    this.projectiles = [];
    this.enemies = [];
    this.completedGame = null;
    this.events = [];
    this.nextProjectileId = 1;
    this.nextEnemyId = 1;
    this.fireCooldownTicks = 0;
    this.player = this.createPlayer();
    this.startNextWave();
  }

  private createPlayer(): PlayerState {
    return {
      x: (this.arena.left + this.arena.right) / 2,
      y: (this.arena.top + this.arena.bottom) / 2,
      radius: this.playerRadius,
      health: this.playerMaxHealth,
      maxHealth: this.playerMaxHealth,
      invulnerableTicks: 0,
      hitFlashTicks: 0,
    };
  }

  private decrementTransientTimers(): void {
    this.player.invulnerableTicks = Math.max(0, this.player.invulnerableTicks - 1);
    this.player.hitFlashTicks = Math.max(0, this.player.hitFlashTicks - 1);
  }

  private movePlayer(input: StepInput): void {
    const horizontal = Number(input.right) - Number(input.left);
    const vertical = Number(input.down) - Number(input.up);
    const direction = normalize(horizontal, vertical);
    const hasMovementInput = horizontal !== 0 || vertical !== 0;
    if (!hasMovementInput) {
      return;
    }

    this.player.x = clamp(
      this.player.x + direction.x * PLAYER_SPEED,
      this.arena.left + this.player.radius,
      this.arena.right - this.player.radius,
    );
    this.player.y = clamp(
      this.player.y + direction.y * PLAYER_SPEED,
      this.arena.top + this.player.radius,
      this.arena.bottom - this.player.radius,
    );
  }

  private decrementFireCooldown(): void {
    this.fireCooldownTicks = Math.max(0, this.fireCooldownTicks - 1);
  }

  private fireProjectile(input: StepInput): void {
    if (!input.fire || this.fireCooldownTicks > 0) {
      return;
    }

    const aimX = finiteOr(input.aimX, this.player.x + 1);
    const aimY = finiteOr(input.aimY, this.player.y);
    const direction = normalize(aimX - this.player.x, aimY - this.player.y);
    const spawnDistance = this.player.radius + PROJECTILE_RADIUS + 2;
    const projectile: ProjectileState = {
      id: this.nextProjectileId,
      x: this.player.x + direction.x * spawnDistance,
      y: this.player.y + direction.y * spawnDistance,
      radius: PROJECTILE_RADIUS,
      velocityX: direction.x * PROJECTILE_SPEED,
      velocityY: direction.y * PROJECTILE_SPEED,
      damage: PROJECTILE_DAMAGE,
      remainingTicks: PROJECTILE_LIFETIME_TICKS,
    };
    this.nextProjectileId += 1;
    this.projectiles.push(projectile);
    this.fireCooldownTicks = FIRE_COOLDOWN_TICKS;
    this.events.push({ type: "shot-fired", projectileId: projectile.id, x: projectile.x, y: projectile.y });
  }

  private moveProjectilesAndResolveHits(): void {
    const remainingProjectiles: ProjectileState[] = [];
    for (const projectile of this.projectiles) {
      projectile.x += projectile.velocityX;
      projectile.y += projectile.velocityY;
      projectile.remainingTicks -= 1;
      if (projectile.remainingTicks <= 0 || !this.isInsideArena(projectile.x, projectile.y, projectile.radius)) {
        continue;
      }

      const enemy = this.enemies.find(
        (candidate) =>
          distanceSquared(projectile.x, projectile.y, candidate.x, candidate.y) <=
          (projectile.radius + candidate.radius) ** 2,
      );
      if (enemy === undefined) {
        remainingProjectiles.push(projectile);
        continue;
      }

      enemy.health -= projectile.damage;
      this.events.push({ type: "enemy-hit", enemyId: enemy.id, x: enemy.x, y: enemy.y });
      if (enemy.health <= 0) {
        this.score += getEnemyStats(enemy.kind, this.wave).score;
        this.events.push({
          type: "enemy-defeated",
          enemyId: enemy.id,
          kind: enemy.kind,
          x: enemy.x,
          y: enemy.y,
          score: getEnemyStats(enemy.kind, this.wave).score,
        });
        this.enemies = this.enemies.filter((candidate) => candidate.id !== enemy.id);
      }
    }
    this.projectiles = remainingProjectiles;
  }

  private moveEnemies(): void {
    for (const enemy of this.enemies) {
      const toPlayerX = this.player.x - enemy.x;
      const toPlayerY = this.player.y - enemy.y;
      const direct = normalize(toPlayerX, toPlayerY);
      let direction = direct;

      if (enemy.kind === "striker") {
        enemy.phase = (enemy.phase + 0.1) % TWO_PI;
        const strafe = Math.sin(enemy.phase) * 0.7;
        direction = normalize(direct.x - direct.y * strafe, direct.y + direct.x * strafe);
      }

      enemy.x = clamp(
        enemy.x + direction.x * enemy.speed,
        this.arena.left + enemy.radius,
        this.arena.right - enemy.radius,
      );
      enemy.y = clamp(
        enemy.y + direction.y * enemy.speed,
        this.arena.top + enemy.radius,
        this.arena.bottom - enemy.radius,
      );
    }
  }

  private resolveContactDamage(): void {
    if (this.player.invulnerableTicks > 0) {
      return;
    }

    const contact = this.enemies.find(
      (enemy) =>
        distanceSquared(this.player.x, this.player.y, enemy.x, enemy.y) <=
        (this.player.radius + enemy.radius) ** 2,
    );
    if (contact === undefined) {
      return;
    }

    this.player.health = Math.max(0, this.player.health - contact.contactDamage);
    this.player.invulnerableTicks = PLAYER_INVULNERABILITY_TICKS;
    this.player.hitFlashTicks = PLAYER_HIT_FLASH_TICKS;
    this.events.push({ type: "player-hit", health: this.player.health, x: this.player.x, y: this.player.y });
    if (this.player.health <= 0) {
      this.finishGame();
    }
  }

  private finishGame(): void {
    this.phase = "game-over";
    this.completedGame = {
      seed: this.seed,
      finalTick: this.tick,
      score: this.score,
      wave: this.wave,
    };
    this.events.push({ type: "game-over", record: { ...this.completedGame } });
  }

  private startNextWave(): void {
    this.wave += 1;
    const count = 3 + this.wave;
    for (let index = 0; index < count; index += 1) {
      this.enemies.push(this.createEnemy(ENEMY_KINDS[(index + this.wave - 1) % ENEMY_KINDS.length]));
    }
    this.events.push({ type: "wave-start", wave: this.wave, count });
  }

  private createEnemy(kind: EnemyKind): EnemyState {
    const stats = getEnemyStats(kind, this.wave);
    const position = this.findSpawnPosition(stats.radius, this.nextEnemyId - 1);
    return {
      id: this.nextEnemyId++,
      kind,
      x: position.x,
      y: position.y,
      radius: stats.radius,
      health: stats.health,
      maxHealth: stats.health,
      speed: stats.speed,
      contactDamage: stats.contactDamage,
      phase: this.random.next() * TWO_PI,
    };
  }

  private findSpawnPosition(radius: number, spawnIndex: number): { x: number; y: number } {
    const minimumX = this.arena.left + radius;
    const maximumX = this.arena.right - radius;
    const minimumY = this.arena.top + radius;
    const maximumY = this.arena.bottom - radius;

    if (this.wave === 1 && this.spawnRadius > 0) {
      const centerX = (this.arena.left + this.arena.right) / 2;
      const centerY = (this.arena.top + this.arena.bottom) / 2;
      const distance = Math.min(
        this.spawnRadius + 72,
        Math.max(0, Math.min((this.arena.right - this.arena.left) / 2 - radius, (this.arena.bottom - this.arena.top) / 2 - radius)),
      );
      const angle = [0, Math.PI, -Math.PI / 2, Math.PI / 2][spawnIndex % 4];
      const cardinalX = clamp(centerX + Math.cos(angle) * distance, minimumX, maximumX);
      const cardinalY = clamp(centerY + Math.sin(angle) * distance, minimumY, maximumY);
      if (distanceSquared(cardinalX, cardinalY, this.player.x, this.player.y) >= this.spawnRadius ** 2) {
        return { x: cardinalX, y: cardinalY };
      }
    }

    for (let attempt = 0; attempt < 48; attempt += 1) {
      const x = minimumX + (maximumX - minimumX) * this.random.next();
      const y = minimumY + (maximumY - minimumY) * this.random.next();
      if (distanceSquared(x, y, this.player.x, this.player.y) >= this.spawnRadius ** 2) {
        return { x: clamp(x, minimumX, maximumX), y: clamp(y, minimumY, maximumY) };
      }
    }

    const candidates = [
      { x: minimumX, y: minimumY },
      { x: minimumX, y: maximumY },
      { x: maximumX, y: minimumY },
      { x: maximumX, y: maximumY },
    ];
    candidates.sort(
      (first, second) =>
        distanceSquared(second.x, second.y, this.player.x, this.player.y) -
        distanceSquared(first.x, first.y, this.player.x, this.player.y),
    );
    return candidates[0];
  }

  private isInsideArena(x: number, y: number, radius: number): boolean {
    return (
      x - radius >= this.arena.left &&
      x + radius <= this.arena.right &&
      y - radius >= this.arena.top &&
      y + radius <= this.arena.bottom
    );
  }
}

export default Simulation;
