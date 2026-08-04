/**
 * Renderer and audio independent simulation for Vector Siege.
 *
 * The simulation advances by exactly one {@link FIXED_TIMESTEP} for every
 * successful call to `step`.  It intentionally contains no Phaser, DOM, or
 * wall-clock dependencies, which makes a scripted run reproducible from its
 * seed and input frames.
 */

export const SIMULATION_HZ = 60;
export const FIXED_TIMESTEP = 1 / SIMULATION_HZ;

const DEFAULT_SEED = 0x1a2b3c4d;
const TAU = Math.PI * 2;

/** A two-dimensional value used for positions, velocities, and aim targets. */
export interface Vector2 {
  x: number;
  y: number;
}

/** Dimensions of the playable rectangular arena. */
export interface ArenaSize {
  width: number;
  height: number;
}

export type SimulationPhase = "menu" | "running" | "paused" | "game-over";

export type EnemyKind = "chaser" | "striker" | "tank";
/** `EnemyType` is kept as a readable alias for consumers that prefer it. */
export type EnemyType = EnemyKind;

/**
 * Input sampled for one fixed simulation tick.
 *
 * `aim`/`aimX`/`aimY` are world-space pointer coordinates.  `aimDirection`
 * can be used when the caller already has a normalized (or non-normalized)
 * direction vector.  Move axes are clamped and normalized by the simulation,
 * so diagonal movement is not faster than cardinal movement.
 */
export interface InputFrame {
  moveX?: number;
  moveY?: number;
  move?: Vector2;
  aim?: Vector2;
  aimX?: number;
  aimY?: number;
  aimDirection?: Vector2;
  fire?: boolean;
  /** Alias useful for keyboard adapters that call the action `shoot`. */
  shoot?: boolean;
  /** Optional aliases for adapters that keep pointer and keyboard actions separate. */
  pointerDown?: boolean;
  space?: boolean;
  /** A pause value is treated as a one-frame toggle/pulse. */
  pause?: boolean;
}

export interface PlayerState {
  position: Vector2;
  velocity: Vector2;
  aimDirection: Vector2;
  health: number;
  maxHealth: number;
  radius: number;
  speed: number;
  invulnerableUntilTick: number;
  isInvulnerable: boolean;
  invulnerabilityTicksRemaining: number;
  hitFlashTicksRemaining: number;
  fireCooldownTicksRemaining: number;
}

export interface EnemyState {
  id: number;
  /** Canonical enemy variant name. */
  kind: EnemyKind;
  /** Alias for callers that model variants as a `type` field. */
  type: EnemyKind;
  position: Vector2;
  velocity: Vector2;
  health: number;
  maxHealth: number;
  radius: number;
  speed: number;
  contactDamage: number;
  scoreValue: number;
  /** Direction used by striker orbiting; it is part of deterministic state. */
  orbitDirection: 1 | -1;
}

export interface ProjectileState {
  id: number;
  position: Vector2;
  velocity: Vector2;
  radius: number;
  damage: number;
  remainingTicks: number;
}

export interface CompletedGame {
  seed: number;
  finalTick: number;
}

export type SimulationEvent =
  | { type: "game-started"; wave: number }
  | { type: "game-paused"; tick: number }
  | { type: "game-resumed"; tick: number }
  | { type: "wave-started"; wave: number; enemyCount: number }
  | { type: "projectile-fired"; projectileId: number }
  | { type: "enemy-hit"; enemyId: number; remainingHealth: number }
  | { type: "enemy-defeated"; enemyId: number; enemyKind: EnemyKind; score: number }
  | { type: "player-damaged"; amount: number; health: number }
  | { type: "projectile-expired"; projectileId: number }
  | { type: "game-over"; seed: number; finalTick: number };

export interface GameState {
  phase: SimulationPhase;
  seed: number;
  tick: number;
  fixedTimestep: number;
  arena: ArenaSize;
  player: PlayerState;
  enemies: EnemyState[];
  projectiles: ProjectileState[];
  score: number;
  wave: number;
  /** A convenient scalar for HUDs and difficulty diagnostics. */
  waveDifficulty: number;
  completedGame: CompletedGame | null;
  /** Completed records are retained across restarts for run-history consumers. */
  completedGames: CompletedGame[];
  /** Events emitted by the most recent lifecycle/tick operation. */
  events: SimulationEvent[];
}

export interface InitialEnemy {
  kind?: EnemyKind;
  /** Alias for `kind` in serialized fixtures. */
  type?: EnemyKind;
  position: Vector2;
  health?: number;
  orbitDirection?: 1 | -1;
}

export interface SimulationOptions {
  /** Any integer or string is converted to a stable unsigned 32-bit seed. */
  seed?: number | string;
  arena?: Partial<ArenaSize>;
  /** Width/height aliases for lightweight shell adapters. */
  width?: number;
  height?: number;
  arenaWidth?: number;
  arenaHeight?: number;
  /** Minimum radial distance at which generated enemies appear. */
  spawnRadius?: number;
  /** Alias for `spawnRadius`. */
  enemySpawnRadius?: number;
  playerStart?: Vector2;
  playerMaxHealth?: number;
  playerSpeed?: number;
  playerRadius?: number;
  invulnerabilityTicks?: number;
  projectileSpeed?: number;
  projectileDamage?: number;
  projectileRadius?: number;
  projectileLifetimeTicks?: number;
  fireCooldownTicks?: number;
  baseEnemyCount?: number;
  enemyCountIncrement?: number;
  /** An explicitly supplied first wave replaces procedural first-wave spawn. */
  initialEnemies?: readonly InitialEnemy[];
}

/** Public configuration values used by the active simulation. */
export interface SimulationConfig {
  arena: ArenaSize;
  spawnRadius: number;
  playerMaxHealth: number;
  playerSpeed: number;
  playerRadius: number;
  invulnerabilityTicks: number;
  projectileSpeed: number;
  projectileDamage: number;
  projectileRadius: number;
  projectileLifetimeTicks: number;
  fireCooldownTicks: number;
  baseEnemyCount: number;
  enemyCountIncrement: number;
  initialEnemies: readonly InitialEnemy[] | null;
}

export interface DeterministicRandom {
  /** Returns a deterministic value in the half-open interval [0, 1). */
  next(): number;
  /** Returns an integer in [0, maxExclusive), or 0 for a non-positive bound. */
  nextInt(maxExclusive: number): number;
  /** Returns a deterministic value in the half-open interval [min, max). */
  nextRange(min: number, max: number): number;
}

/**
 * A small xorshift32 PRNG.  It is deliberately exported so deterministic
 * fixtures can use the same seed normalization as the simulation itself.
 */
export function createDeterministicRandom(seed: number | string): DeterministicRandom {
  let value = normalizeSeed(seed);
  // xorshift32 has an absorbing zero state; preserve the public seed while
  // using a non-zero internal state for a caller-supplied seed of zero.
  if (value === 0) value = 0x6d2b79f5;

  const next = (): number => {
    value ^= value << 13;
    value ^= value >>> 17;
    value ^= value << 5;
    value >>>= 0;
    return value / 0x100000000;
  };

  return {
    next,
    nextInt(maxExclusive: number): number {
      if (!Number.isFinite(maxExclusive) || maxExclusive <= 0) return 0;
      return Math.floor(next() * Math.floor(maxExclusive));
    },
    nextRange(min: number, max: number): number {
      return min + (max - min) * next();
    },
  };
}

/** Alias with the common `Rng` spelling. */
export const createDeterministicRng = createDeterministicRandom;

export interface SpawnEnemyOptions {
  kind?: EnemyKind;
  type?: EnemyKind;
  position?: Vector2;
  health?: number;
  orbitDirection?: 1 | -1;
}

export interface Simulation {
  /** The live plain-data state; no renderer or audio object is stored here. */
  readonly state: GameState;
  readonly config: SimulationConfig;
  readonly fixedTimestep: number;
  readonly random: DeterministicRandom;
  start(): GameState;
  pause(): GameState;
  resume(): GameState;
  /** Reset the run with the original seed and immediately enter `running`. */
  restart(): GameState;
  /** Advance one deterministic fixed timestep when the phase is `running`. */
  step(input?: InputFrame): GameState;
  /** Readable alias for integrations that call their fixed update `update`. */
  update(input?: InputFrame): GameState;
  /** Add an enemy for setup tools and deterministic test fixtures. */
  spawnEnemy(kind: EnemyKind, position?: Vector2): EnemyState;
  spawnEnemy(options: SpawnEnemyOptions): EnemyState;
  /** Apply contact-equivalent damage through the same invulnerability rules. */
  damagePlayer(amount: number): boolean;
}

interface EnemyStats {
  health: number;
  speed: number;
  radius: number;
  contactDamage: number;
  scoreValue: number;
}

const ENEMY_BASE_STATS: Record<EnemyKind, EnemyStats> = {
  chaser: {
    health: 1,
    speed: 108,
    radius: 16,
    contactDamage: 1,
    scoreValue: 100,
  },
  striker: {
    health: 2,
    speed: 82,
    radius: 14,
    contactDamage: 1,
    scoreValue: 150,
  },
  tank: {
    health: 5,
    speed: 48,
    radius: 24,
    contactDamage: 2,
    scoreValue: 300,
  },
};

function normalizeSeed(seed: number | string): number {
  if (typeof seed === "number" && Number.isFinite(seed)) {
    return Math.trunc(seed) >>> 0;
  }

  const text = String(seed);
  let hash = 2166136261;
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function copyVector(value: Vector2): Vector2 {
  return { x: value.x, y: value.y };
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function finiteOr(value: number | undefined, fallback: number): number {
  return value !== undefined && Number.isFinite(value) ? value : fallback;
}

function positiveOr(value: number | undefined, fallback: number): number {
  const candidate = finiteOr(value, fallback);
  return candidate > 0 ? candidate : fallback;
}

function nonNegativeOr(value: number | undefined, fallback: number): number {
  const candidate = finiteOr(value, fallback);
  return candidate >= 0 ? candidate : fallback;
}

function normalizeVector(vector: Vector2, fallback: Vector2 = { x: 0, y: 0 }): Vector2 {
  const x = finiteOr(vector.x, fallback.x);
  const y = finiteOr(vector.y, fallback.y);
  const length = Math.hypot(x, y);
  return length > 0.000001 ? { x: x / length, y: y / length } : copyVector(fallback);
}

function distanceSquared(a: Vector2, b: Vector2): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return dx * dx + dy * dy;
}

function pointInsideArena(position: Vector2, radius: number, arena: ArenaSize): Vector2 {
  return {
    x: clamp(position.x, radius, Math.max(radius, arena.width - radius)),
    y: clamp(position.y, radius, Math.max(radius, arena.height - radius)),
  };
}

function segmentIntersectsCircle(
  start: Vector2,
  end: Vector2,
  center: Vector2,
  radius: number,
): boolean {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared <= 0.000001) return distanceSquared(start, center) <= radius * radius;

  const projection = ((center.x - start.x) * dx + (center.y - start.y) * dy) / lengthSquared;
  const t = clamp(projection, 0, 1);
  const closest = { x: start.x + dx * t, y: start.y + dy * t };
  return distanceSquared(closest, center) <= radius * radius;
}

function createConfig(options: SimulationOptions): SimulationConfig {
  const width = positiveOr(options.arena?.width, positiveOr(options.width ?? options.arenaWidth, 1280));
  const height = positiveOr(options.arena?.height, positiveOr(options.height ?? options.arenaHeight, 720));
  return {
    arena: { width, height },
    spawnRadius: nonNegativeOr(options.spawnRadius ?? options.enemySpawnRadius, 280),
    playerMaxHealth: positiveOr(options.playerMaxHealth, 5),
    playerSpeed: positiveOr(options.playerSpeed, 250),
    playerRadius: positiveOr(options.playerRadius, 18),
    invulnerabilityTicks: Math.max(1, Math.floor(positiveOr(options.invulnerabilityTicks, 36))),
    projectileSpeed: positiveOr(options.projectileSpeed, 560),
    projectileDamage: positiveOr(options.projectileDamage, 1),
    projectileRadius: positiveOr(options.projectileRadius, 5),
    projectileLifetimeTicks: Math.max(1, Math.floor(positiveOr(options.projectileLifetimeTicks, 90))),
    fireCooldownTicks: Math.max(1, Math.floor(positiveOr(options.fireCooldownTicks, 8))),
    baseEnemyCount: Math.max(1, Math.floor(positiveOr(options.baseEnemyCount, 3))),
    enemyCountIncrement: Math.max(0, Math.floor(finiteOr(options.enemyCountIncrement, 2))),
    initialEnemies: options.initialEnemies ? options.initialEnemies.map(copyInitialEnemy) : null,
  };
}

function copyInitialEnemy(enemy: InitialEnemy): InitialEnemy {
  return {
    kind: enemy.kind,
    type: enemy.type,
    position: copyVector(enemy.position),
    health: enemy.health,
    orbitDirection: enemy.orbitDirection,
  };
}

function createPlayer(config: SimulationConfig, start?: Vector2): PlayerState {
  const requested = start ?? {
    x: config.arena.width / 2,
    y: config.arena.height / 2,
  };
  const position = pointInsideArena(requested, config.playerRadius, config.arena);
  return {
    position,
    velocity: { x: 0, y: 0 },
    aimDirection: { x: 1, y: 0 },
    health: config.playerMaxHealth,
    maxHealth: config.playerMaxHealth,
    radius: config.playerRadius,
    speed: config.playerSpeed,
    invulnerableUntilTick: 0,
    isInvulnerable: false,
    invulnerabilityTicksRemaining: 0,
    hitFlashTicksRemaining: 0,
    fireCooldownTicksRemaining: 0,
  };
}

function createState(seed: number, config: SimulationConfig, playerStart?: Vector2): GameState {
  return {
    phase: "menu",
    seed,
    tick: 0,
    fixedTimestep: FIXED_TIMESTEP,
    arena: { width: config.arena.width, height: config.arena.height },
    player: createPlayer(config, playerStart),
    enemies: [],
    projectiles: [],
    score: 0,
    wave: 0,
    waveDifficulty: 1,
    completedGame: null,
    completedGames: [],
    events: [],
  };
}

class VectorSiegeSimulation implements Simulation {
  public readonly config: SimulationConfig;
  public readonly fixedTimestep = FIXED_TIMESTEP;
  public readonly random: DeterministicRandom;
  private readonly seed: number;
  private readonly playerStart: Vector2 | undefined;
  private readonly initialEnemies: readonly InitialEnemy[] | null;
  private stateValue: GameState;
  private nextEnemyId = 1;
  private nextProjectileId = 1;
  private readonly projectilePreviousPositions = new Map<number, Vector2>();

  public constructor(options: SimulationOptions = {}) {
    this.seed = normalizeSeed(options.seed ?? DEFAULT_SEED);
    this.config = createConfig(options);
    this.playerStart = options.playerStart ? copyVector(options.playerStart) : undefined;
    this.initialEnemies = this.config.initialEnemies;
    this.random = createDeterministicRandom(this.seed);
    this.stateValue = createState(this.seed, this.config, this.playerStart);
  }

  public get state(): GameState {
    return this.stateValue;
  }

  public start(): GameState {
    if (this.stateValue.phase === "running") return this.stateValue;
    if (this.stateValue.phase === "paused") return this.resume();
    if (this.stateValue.phase === "game-over") return this.restart();

    this.stateValue.phase = "running";
    this.stateValue.wave = 1;
    this.stateValue.waveDifficulty = difficultyForWave(this.stateValue.wave);
    this.stateValue.events = [{ type: "game-started", wave: this.stateValue.wave }];
    this.spawnWave(this.stateValue.wave, this.initialEnemies);
    return this.stateValue;
  }

  public pause(): GameState {
    if (this.stateValue.phase === "running") {
      this.stateValue.phase = "paused";
      this.stateValue.events = [{ type: "game-paused", tick: this.stateValue.tick }];
    }
    return this.stateValue;
  }

  public resume(): GameState {
    if (this.stateValue.phase === "paused") {
      this.stateValue.phase = "running";
      this.stateValue.events = [{ type: "game-resumed", tick: this.stateValue.tick }];
    }
    return this.stateValue;
  }

  public restart(): GameState {
    const completedGames = this.stateValue.completedGames.map(copyCompletedGame);
    this.stateValue = createState(this.seed, this.config, this.playerStart);
    this.stateValue.completedGames = completedGames;
    this.nextEnemyId = 1;
    this.nextProjectileId = 1;
    this.projectilePreviousPositions.clear();
    this.resetRandom();
    return this.start();
  }

  public step(input: InputFrame = {}): GameState {
    if (input.pause) {
      if (this.stateValue.phase === "running") return this.pause();
      if (this.stateValue.phase === "paused") return this.resume();
    }

    if (this.stateValue.phase !== "running") return this.stateValue;

    this.stateValue.events = [];
    this.stateValue.tick += 1;
    this.updatePlayer(input);
    this.updateProjectiles();
    this.updateEnemies();
    this.resolveProjectileCollisions();
    this.resolveContactDamage();
    this.updatePlayerTimers();

    if (this.stateValue.phase === "running" && this.stateValue.enemies.length === 0) {
      this.stateValue.wave += 1;
      this.stateValue.waveDifficulty = difficultyForWave(this.stateValue.wave);
      this.spawnWave(this.stateValue.wave);
    }

    return this.stateValue;
  }

  public update(input: InputFrame = {}): GameState {
    return this.step(input);
  }

  public spawnEnemy(kind: EnemyKind, position?: Vector2): EnemyState;
  public spawnEnemy(options: SpawnEnemyOptions): EnemyState;
  public spawnEnemy(
    kindOrOptions: EnemyKind | SpawnEnemyOptions,
    position?: Vector2,
  ): EnemyState {
    const options: SpawnEnemyOptions = typeof kindOrOptions === "string"
      ? { kind: kindOrOptions, position }
      : kindOrOptions;
    const kind = options.kind ?? options.type ?? "chaser";
    const enemy = this.createEnemy(kind, options.position, this.stateValue.wave || 1, options);
    this.stateValue.enemies.push(enemy);
    return enemy;
  }

  public damagePlayer(amount: number): boolean {
    if (this.stateValue.phase !== "running") return false;
    return this.applyPlayerDamage(amount);
  }

  private resetRandom(): void {
    // The exported PRNG is stateful, so restart needs a fresh instance.  The
    // property is assigned through a narrowly scoped cast to retain the
    // simple readonly consumer-facing API.
    (this as { random: DeterministicRandom }).random = createDeterministicRandom(this.seed);
  }

  private spawnWave(wave: number, explicitEnemies?: readonly InitialEnemy[] | null): void {
    const definitions = explicitEnemies ?? this.createWaveDefinitions(wave);
    for (const definition of definitions) {
      this.spawnEnemy({
        kind: definition.kind ?? definition.type ?? "chaser",
        position: definition.position,
        health: definition.health,
        orbitDirection: definition.orbitDirection,
      });
    }
    this.stateValue.events.push({
      type: "wave-started",
      wave,
      enemyCount: definitions.length,
    });
  }

  private createWaveDefinitions(wave: number): InitialEnemy[] {
    const count = this.config.baseEnemyCount + this.config.enemyCountIncrement * (wave - 1);
    const definitions: InitialEnemy[] = [];
    for (let index = 0; index < count; index += 1) {
      let kind: EnemyKind = "chaser";
      if (wave === 1 && index === count - 1) {
        kind = "striker";
      } else if (wave >= 3 && index % 5 === 4) {
        kind = "tank";
      } else if (wave >= 2 && index % 3 === 2) {
        kind = "striker";
      }
      definitions.push({
        kind,
        position: this.findSpawnPosition(ENEMY_BASE_STATS[kind].radius),
        orbitDirection: index % 2 === 0 ? 1 : -1,
      });
    }
    return definitions;
  }

  private findSpawnPosition(enemyRadius: number): Vector2 {
    const player = this.stateValue.player.position;
    const minimumDistance = this.config.spawnRadius;
    const candidateDistance = Math.max(minimumDistance + 1, minimumDistance);
    const maxAttempts = 40;
    let farthest = copyVector(player);
    let farthestDistance = -1;

    for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
      const angle = this.random.nextRange(0, TAU);
      const distance = candidateDistance + this.random.nextRange(0, 48);
      const raw = {
        x: player.x + Math.cos(angle) * distance,
        y: player.y + Math.sin(angle) * distance,
      };
      const candidate = pointInsideArena(raw, enemyRadius, this.stateValue.arena);
      const actualDistance = Math.sqrt(distanceSquared(candidate, player));
      if (actualDistance > farthestDistance) {
        farthest = candidate;
        farthestDistance = actualDistance;
      }
      if (actualDistance >= minimumDistance) return candidate;
    }

    // A very large configured radius may not fit in the arena.  Returning the
    // farthest valid point is the only safe fallback while preserving bounds.
    return farthest;
  }

  private createEnemy(
    kind: EnemyKind,
    position: Vector2 | undefined,
    wave: number,
    options: SpawnEnemyOptions = {},
  ): EnemyState {
    const safeKind: EnemyKind = Object.prototype.hasOwnProperty.call(ENEMY_BASE_STATS, kind)
      ? kind
      : "chaser";
    const base = ENEMY_BASE_STATS[safeKind];
    const difficulty = difficultyForWave(wave);
    const health = Math.max(1, Math.ceil((options.health ?? base.health) * difficulty));
    const safePosition = pointInsideArena(
      position ?? this.findSpawnPosition(base.radius),
      base.radius,
      this.stateValue.arena,
    );
    return {
      id: this.nextEnemyId++,
      kind: safeKind,
      type: safeKind,
      position: safePosition,
      velocity: { x: 0, y: 0 },
      health,
      maxHealth: health,
      radius: base.radius,
      speed: base.speed * (1 + (difficulty - 1) * 0.55),
      contactDamage: base.contactDamage,
      scoreValue: Math.round(base.scoreValue * difficulty),
      orbitDirection: options.orbitDirection ?? (this.nextEnemyId % 2 === 0 ? 1 : -1),
    };
  }

  private updatePlayer(input: InputFrame): void {
    const moveX = finiteOr(input.moveX, finiteOr(input.move?.x, 0));
    const moveY = finiteOr(input.moveY, finiteOr(input.move?.y, 0));
    const rawMove = { x: clamp(moveX, -1, 1), y: clamp(moveY, -1, 1) };
    const move = normalizeVector(rawMove);
    this.stateValue.player.velocity = {
      x: move.x * this.stateValue.player.speed,
      y: move.y * this.stateValue.player.speed,
    };
    this.stateValue.player.position = pointInsideArena(
      {
        x: this.stateValue.player.position.x + this.stateValue.player.velocity.x * FIXED_TIMESTEP,
        y: this.stateValue.player.position.y + this.stateValue.player.velocity.y * FIXED_TIMESTEP,
      },
      this.stateValue.player.radius,
      this.stateValue.arena,
    );

    const aimDirection = this.resolveAimDirection(input);
    this.stateValue.player.aimDirection = aimDirection;
    if (this.stateValue.player.fireCooldownTicksRemaining > 0) {
      this.stateValue.player.fireCooldownTicksRemaining -= 1;
    }
    if ((input.fire || input.shoot || input.pointerDown || input.space)
      && this.stateValue.player.fireCooldownTicksRemaining <= 0) {
      this.fireProjectile(aimDirection);
    }
  }

  private resolveAimDirection(input: InputFrame): Vector2 {
    if (input.aimDirection) return normalizeVector(input.aimDirection, this.stateValue.player.aimDirection);

    const target = input.aim ?? (
      input.aimX !== undefined || input.aimY !== undefined
        ? { x: finiteOr(input.aimX, this.stateValue.player.position.x), y: finiteOr(input.aimY, this.stateValue.player.position.y) }
        : undefined
    );
    if (!target) return copyVector(this.stateValue.player.aimDirection);

    // Accept a compact direction in `aim` as well as the documented world
    // target form.  Explicit `aimDirection` remains available when a caller
    // wants to remove this small-vector ambiguity entirely.
    if (Math.hypot(target.x, target.y) <= 1.5) {
      return normalizeVector(target, this.stateValue.player.aimDirection);
    }

    const relative = {
      x: target.x - this.stateValue.player.position.x,
      y: target.y - this.stateValue.player.position.y,
    };
    return normalizeVector(relative, this.stateValue.player.aimDirection);
  }

  private fireProjectile(direction: Vector2): void {
    const radius = this.config.projectileRadius;
    const start = {
      x: this.stateValue.player.position.x + direction.x * (this.stateValue.player.radius + radius + 1),
      y: this.stateValue.player.position.y + direction.y * (this.stateValue.player.radius + radius + 1),
    };
    const projectile: ProjectileState = {
      id: this.nextProjectileId++,
      position: start,
      velocity: {
        x: direction.x * this.config.projectileSpeed,
        y: direction.y * this.config.projectileSpeed,
      },
      radius,
      damage: this.config.projectileDamage,
      remainingTicks: this.config.projectileLifetimeTicks,
    };
    this.stateValue.projectiles.push(projectile);
    this.stateValue.player.fireCooldownTicksRemaining = this.config.fireCooldownTicks;
    this.stateValue.events.push({ type: "projectile-fired", projectileId: projectile.id });
  }

  private updateProjectiles(): void {
    const active: ProjectileState[] = [];
    this.projectilePreviousPositions.clear();
    for (const projectile of this.stateValue.projectiles) {
      const previous = copyVector(projectile.position);
      projectile.position.x += projectile.velocity.x * FIXED_TIMESTEP;
      projectile.position.y += projectile.velocity.y * FIXED_TIMESTEP;
      projectile.remainingTicks -= 1;
      const outside = projectile.position.x < -projectile.radius
        || projectile.position.x > this.stateValue.arena.width + projectile.radius
        || projectile.position.y < -projectile.radius
        || projectile.position.y > this.stateValue.arena.height + projectile.radius;
      if (outside || projectile.remainingTicks <= 0) {
        this.stateValue.events.push({ type: "projectile-expired", projectileId: projectile.id });
      } else {
        // Keep the previous position in simulation-private data for swept
        // collision testing without leaking renderer-only bookkeeping onto the
        // plain public projectile entity.
        this.projectilePreviousPositions.set(projectile.id, previous);
        active.push(projectile);
      }
    }
    this.stateValue.projectiles = active;
  }

  private updateEnemies(): void {
    const player = this.stateValue.player.position;
    for (const enemy of this.stateValue.enemies) {
      const toPlayer = { x: player.x - enemy.position.x, y: player.y - enemy.position.y };
      const pursuit = normalizeVector(toPlayer);
      if (enemy.kind === "striker") {
        const orbit = { x: -pursuit.y * enemy.orbitDirection, y: pursuit.x * enemy.orbitDirection };
        const steering = normalizeVector({
          x: pursuit.x * 0.58 + orbit.x * 0.82,
          y: pursuit.y * 0.58 + orbit.y * 0.82,
        }, pursuit);
        enemy.velocity = { x: steering.x * enemy.speed, y: steering.y * enemy.speed };
      } else {
        // Chasers and tanks use direct pursuit; their distinct stats still
        // make tank waves materially slower, tougher, and more damaging.
        enemy.velocity = { x: pursuit.x * enemy.speed, y: pursuit.y * enemy.speed };
      }
      enemy.position = pointInsideArena(
        {
          x: enemy.position.x + enemy.velocity.x * FIXED_TIMESTEP,
          y: enemy.position.y + enemy.velocity.y * FIXED_TIMESTEP,
        },
        enemy.radius,
        this.stateValue.arena,
      );
    }
  }

  private resolveProjectileCollisions(): void {
    const remainingProjectiles: ProjectileState[] = [];
    const remainingEnemies = [...this.stateValue.enemies];
    for (const projectile of this.stateValue.projectiles) {
      const previous = this.projectilePreviousPositions.get(projectile.id) ?? projectile.position;
      let hit = false;
      for (let enemyIndex = 0; enemyIndex < remainingEnemies.length; enemyIndex += 1) {
        const enemy = remainingEnemies[enemyIndex];
        if (!segmentIntersectsCircle(previous, projectile.position, enemy.position, projectile.radius + enemy.radius)) {
          continue;
        }
        hit = true;
        enemy.health -= projectile.damage;
        if (enemy.health <= 0) {
          remainingEnemies.splice(enemyIndex, 1);
          this.stateValue.score += enemy.scoreValue;
          this.stateValue.events.push({
            type: "enemy-defeated",
            enemyId: enemy.id,
            enemyKind: enemy.kind,
            score: enemy.scoreValue,
          });
        } else {
          this.stateValue.events.push({
            type: "enemy-hit",
            enemyId: enemy.id,
            remainingHealth: enemy.health,
          });
        }
        break;
      }
      if (!hit) remainingProjectiles.push(projectile);
    }
    this.stateValue.projectiles = remainingProjectiles;
    this.stateValue.enemies = remainingEnemies;
    this.projectilePreviousPositions.clear();
  }

  private resolveContactDamage(): void {
    const player = this.stateValue.player;
    for (const enemy of this.stateValue.enemies) {
      const collisionDistance = player.radius + enemy.radius;
      if (distanceSquared(player.position, enemy.position) <= collisionDistance * collisionDistance) {
        if (this.applyPlayerDamage(enemy.contactDamage)) break;
      }
    }
  }

  private applyPlayerDamage(amount: number): boolean {
    if (!Number.isFinite(amount) || amount <= 0) return false;
    const player = this.stateValue.player;
    if (this.stateValue.tick < player.invulnerableUntilTick) return false;

    const damage = Math.max(0, amount);
    player.health = Math.max(0, player.health - damage);
    player.invulnerableUntilTick = this.stateValue.tick + this.config.invulnerabilityTicks;
    player.isInvulnerable = true;
    player.invulnerabilityTicksRemaining = this.config.invulnerabilityTicks;
    player.hitFlashTicksRemaining = Math.min(8, this.config.invulnerabilityTicks);
    this.stateValue.events.push({ type: "player-damaged", amount: damage, health: player.health });
    if (player.health <= 0) this.endGame();
    return true;
  }

  private updatePlayerTimers(): void {
    const player = this.stateValue.player;
    player.invulnerabilityTicksRemaining = Math.max(0, player.invulnerableUntilTick - this.stateValue.tick);
    player.isInvulnerable = player.invulnerabilityTicksRemaining > 0;
    player.hitFlashTicksRemaining = Math.max(0, player.hitFlashTicksRemaining - 1);
  }

  private endGame(): void {
    if (this.stateValue.phase === "game-over") return;
    const completedGame: CompletedGame = {
      seed: this.stateValue.seed,
      finalTick: this.stateValue.tick,
    };
    this.stateValue.phase = "game-over";
    this.stateValue.completedGame = completedGame;
    this.stateValue.completedGames.push(copyCompletedGame(completedGame));
    this.stateValue.events.push({
      type: "game-over",
      seed: completedGame.seed,
      finalTick: completedGame.finalTick,
    });
  }
}

function difficultyForWave(wave: number): number {
  return 1 + Math.max(0, wave - 1) * 0.15;
}

function copyCompletedGame(record: CompletedGame): CompletedGame {
  return { seed: record.seed, finalTick: record.finalTick };
}

/** Construct a deterministic Vector Siege simulation in the menu phase. */
export function createSimulation(options: SimulationOptions = {}): Simulation {
  return new VectorSiegeSimulation(options);
}

/** `SimulationState` is an alias for consumers that use the factory name. */
export type SimulationState = GameState;
