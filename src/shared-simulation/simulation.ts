import { SeededRandom } from "./random";
import type {
  ArenaSize,
  CompletedGameRecord,
  EnemyState,
  EnemyStatOverride,
  EnemyVariant,
  Point,
  ProjectileState,
  SimulationConfig,
  SimulationEvent,
  SimulationInput,
  SimulationState,
  StartOptions,
} from "./types";

const DEFAULT_ARENA: ArenaSize = { width: 1280, height: 720 };
const DEFAULT_PLAYER_START: Point = { x: 640, y: 360 };
const DEFAULT_STATS: Record<EnemyVariant, EnemyStatOverride> = {
  chaser: { health: 1, speed: 108, radius: 16, contactDamage: 1, scoreValue: 100 },
  striker: { health: 2, speed: 82, radius: 14, contactDamage: 1, scoreValue: 150 },
  tank: { health: 5, speed: 48, radius: 24, contactDamage: 2, scoreValue: 300 },
};
const TAU = Math.PI * 2;

interface ResolvedConfig {
  arena: ArenaSize;
  playerStart: Point;
  playerRadius: number;
  playerSpeed: number;
  playerMaxHealth: number;
  invulnerabilityTicks: number;
  projectileSpeed: number;
  projectileRadius: number;
  projectileDamage: number;
  projectileLifetimeTicks: number;
  fireCooldownTicks: number;
  spawnRadius: number;
  initialEnemiesPerWave: number;
  waveEnemyGrowth: number;
  maxCatchUpSteps: number;
  enemyStats: Record<EnemyVariant, EnemyStatOverride>;
}

const positive = (value: number | undefined, fallback: number): number =>
  value !== undefined && Number.isFinite(value) && value > 0 ? value : fallback;

const integerAtLeast = (value: number | undefined, fallback: number, minimum: number): number =>
  value !== undefined && Number.isFinite(value) && value >= minimum ? Math.floor(value) : fallback;

const clonePoint = (point: Point): Point => ({ x: point.x, y: point.y });

const distanceSquared = (first: Point, second: Point): number => {
  const dx = first.x - second.x;
  const dy = first.y - second.y;
  return dx * dx + dy * dy;
};

const segmentIntersectsCircle = (start: Point, end: Point, center: Point, radius: number): boolean => {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const lengthSquared = dx * dx + dy * dy;
  const projection = lengthSquared === 0
    ? 0
    : clamp(((center.x - start.x) * dx + (center.y - start.y) * dy) / lengthSquared, 0, 1);
  const closest = { x: start.x + dx * projection, y: start.y + dy * projection };
  return distanceSquared(closest, center) <= radius ** 2;
};

const normalized = (x: number, y: number): Point => {
  const length = Math.hypot(x, y);
  return length > 0 ? { x: x / length, y: y / length } : { x: 0, y: 0 };
};

const clamp = (value: number, min: number, max: number): number => Math.min(max, Math.max(min, value));

export class VectorSiegeSimulation {
  public readonly fixedStepMs = 1000 / 60;

  private readonly config: ResolvedConfig;
  private random: SeededRandom;
  private accumulatorMs = 0;
  private nextEntityId = 1;
  private lastAim: Point;
  private fireCooldown = 0;
  private waveHasSpawned = false;
  private projectileStarts = new Map<number, Point>();
  private events: SimulationEvent[] = [];
  private state: SimulationState;

  public constructor(config: SimulationConfig = {}) {
    const arena = config.arena ?? DEFAULT_ARENA;
    if (arena.width <= 0 || arena.height <= 0) throw new Error("Arena dimensions must be positive");

    this.config = {
      arena: { width: arena.width, height: arena.height },
      playerStart: clonePoint(config.playerStart ?? DEFAULT_PLAYER_START),
      playerRadius: positive(config.playerRadius, 16),
      playerSpeed: positive(config.playerSpeed, 240),
      playerMaxHealth: integerAtLeast(config.playerMaxHealth, 5, 1),
      invulnerabilityTicks: integerAtLeast(config.invulnerabilityTicks, 30, 0),
      projectileSpeed: positive(config.projectileSpeed, 600),
      projectileRadius: positive(config.projectileRadius, 5),
      projectileDamage: positive(config.projectileDamage, 1),
      projectileLifetimeTicks: integerAtLeast(config.projectileLifetimeTicks, 90, 1),
      fireCooldownTicks: integerAtLeast(config.fireCooldownTicks, 8, 1),
      spawnRadius: positive(config.spawnRadius, 360),
      initialEnemiesPerWave: integerAtLeast(config.initialEnemiesPerWave, 3, 0),
      waveEnemyGrowth: integerAtLeast(config.waveEnemyGrowth, 1, 0),
      maxCatchUpSteps: integerAtLeast(config.maxCatchUpSteps, 8, 1),
      enemyStats: {
        chaser: { ...DEFAULT_STATS.chaser, ...config.enemyStats?.chaser },
        striker: { ...DEFAULT_STATS.striker, ...config.enemyStats?.striker },
        tank: { ...DEFAULT_STATS.tank, ...config.enemyStats?.tank },
      },
    };
    this.random = new SeededRandom(config.seed ?? 1);
    this.lastAim = { x: this.config.playerStart.x + 1, y: this.config.playerStart.y };
    this.state = this.createState(config.seed ?? 1);
  }

  public start(options: StartOptions = {}): SimulationState {
    if (this.state.status === "paused" || this.state.status === "running") return this.getState();
    this.resetRuntime(this.state.seed, "running");
    if (options.spawnWave !== false) this.startWave();
    this.events.push({ type: "started", tick: this.state.tick, wave: this.state.wave });
    return this.getState();
  }

  public restart(seed = this.state.seed): SimulationState {
    this.resetRuntime(seed, "running");
    this.startWave();
    this.events.push({ type: "restarted", tick: this.state.tick, wave: this.state.wave });
    return this.getState();
  }

  public pause(): SimulationState {
    if (this.state.status === "running") {
      this.state.status = "paused";
      this.events.push({ type: "paused", tick: this.state.tick });
    }
    return this.getState();
  }

  public resume(): SimulationState {
    if (this.state.status === "paused") {
      this.state.status = "running";
      this.events.push({ type: "resumed", tick: this.state.tick });
    }
    return this.getState();
  }

  public step(input: SimulationInput = {}): SimulationState {
    if (this.state.status !== "running") return this.getState();
    this.state.tick += 1;
    this.decrementTransientTimers();
    const normalizedInput = this.resolveInput(input);
    this.movePlayer(normalizedInput);
    if (normalizedInput.fire && this.fireCooldown === 0) this.fire(normalizedInput.aim);
    this.moveProjectiles();
    this.moveEnemies();
    this.resolveProjectileCollisions();
    this.resolvePlayerContacts();
    this.finishIfDead();
    if (this.state.status === "running" && this.state.enemies.length === 0 && this.waveHasSpawned) {
      this.startNextWave();
    }
    return this.getState();
  }

  public advance(elapsedMs: number, input: SimulationInput = {}): SimulationState {
    if (!Number.isFinite(elapsedMs) || elapsedMs <= 0 || this.state.status !== "running") return this.getState();
    this.accumulatorMs += elapsedMs;
    let steps = 0;
    while (this.accumulatorMs >= this.fixedStepMs && steps < this.config.maxCatchUpSteps) {
      this.accumulatorMs -= this.fixedStepMs;
      this.step(input);
      steps += 1;
      if (this.state.status !== "running") break;
    }
    if (steps === this.config.maxCatchUpSteps && this.accumulatorMs >= this.fixedStepMs) {
      this.accumulatorMs = 0;
    }
    return this.getState();
  }

  public spawnEnemy(variant: EnemyVariant, position?: Point): number {
    const stats = this.config.enemyStats[variant];
    const enemy: EnemyState = {
      id: this.nextEntityId++,
      variant,
      ...(position ? clonePoint(position) : this.findSpawnPosition(stats.radius ?? 16)),
      radius: stats.radius ?? 16,
      health: stats.health ?? 1,
      maxHealth: stats.health ?? 1,
      speed: stats.speed ?? 1,
      contactDamage: stats.contactDamage ?? 1,
      scoreValue: stats.scoreValue ?? 100,
    };
    this.state.enemies.push(enemy);
    this.events.push({ type: "enemy-spawned", tick: this.state.tick, enemyId: enemy.id, variant });
    return enemy.id;
  }

  public getState(): SimulationState {
    return {
      ...this.state,
      player: { ...this.state.player },
      projectiles: this.state.projectiles.map((projectile) => ({ ...projectile })),
      enemies: this.state.enemies.map((enemy) => ({ ...enemy })),
      terminal: this.state.terminal ? { ...this.state.terminal } : null,
    };
  }

  public drainEvents(): SimulationEvent[] {
    const pending = this.events;
    this.events = [];
    return pending.map((event) => ({ ...event }));
  }

  private createState(seed: number): SimulationState {
    const player = this.clampPoint(this.config.playerStart, this.config.playerRadius);
    return {
      status: "menu",
      seed: Math.trunc(seed),
      tick: 0,
      wave: 1,
      score: 0,
      player: {
        ...player,
        radius: this.config.playerRadius,
        health: this.config.playerMaxHealth,
        maxHealth: this.config.playerMaxHealth,
        invulnerableTicks: 0,
        hitFlashTicks: 0,
      },
      projectiles: [],
      enemies: [],
      terminal: null,
    };
  }

  private resetRuntime(seed: number, status: "menu" | "running"): void {
    this.random = new SeededRandom(seed);
    this.nextEntityId = 1;
    this.accumulatorMs = 0;
    this.fireCooldown = 0;
    this.waveHasSpawned = false;
    this.projectileStarts.clear();
    this.lastAim = { x: this.config.playerStart.x + 1, y: this.config.playerStart.y };
    this.state = this.createState(seed);
    this.state.status = status;
  }

  private startWave(): void {
    const count = this.config.initialEnemiesPerWave + (this.state.wave - 1) * this.config.waveEnemyGrowth;
    this.waveHasSpawned = count > 0;
    this.events.push({ type: "wave-started", tick: this.state.tick, wave: this.state.wave, count });
    for (let index = 0; index < count; index += 1) this.spawnEnemy(this.variantFor(index, count));
  }

  private startNextWave(): void {
    this.state.wave += 1;
    this.startWave();
  }

  private variantFor(index: number, count: number): EnemyVariant {
    if (this.state.wave === 1 && count > 1) {
      if (index === 0) return "chaser";
      if (index === 1) return "striker";
    }
    if (this.state.wave >= 3 && index % 5 === 0) return "tank";
    return this.random.next() < 0.5 ? "chaser" : "striker";
  }

  private resolveInput(input: SimulationInput): { moveX: number; moveY: number; aim: Point; fire: boolean } {
    const keys = input.keys ?? {};
    const keyX = (keys.d || keys.arrowright ? 1 : 0) - (keys.a || keys.arrowleft ? 1 : 0);
    const keyY = (keys.s || keys.arrowdown ? 1 : 0) - (keys.w || keys.arrowup ? 1 : 0);
    const moveX = clamp(input.moveX ?? keyX, -1, 1);
    const moveY = clamp(input.moveY ?? keyY, -1, 1);
    const pointer = input.pointer ?? input.aim;
    const aim = pointer ? clonePoint(pointer) : clonePoint(this.lastAim);
    const fire = Boolean(input.fire || input.pointer?.down || keys.space);
    return { moveX, moveY, aim, fire };
  }

  private decrementTransientTimers(): void {
    this.fireCooldown = Math.max(0, this.fireCooldown - 1);
    this.state.player.invulnerableTicks = Math.max(0, this.state.player.invulnerableTicks - 1);
    this.state.player.hitFlashTicks = Math.max(0, this.state.player.hitFlashTicks - 1);
  }

  private movePlayer(input: { moveX: number; moveY: number }): void {
    const direction = normalized(input.moveX, input.moveY);
    this.state.player.x += direction.x * this.config.playerSpeed / 60;
    this.state.player.y += direction.y * this.config.playerSpeed / 60;
    Object.assign(this.state.player, this.clampPoint(this.state.player, this.state.player.radius));
  }

  private fire(aim: Point): void {
    const direction = normalized(aim.x - this.state.player.x, aim.y - this.state.player.y);
    if (direction.x === 0 && direction.y === 0) return;
    const projectile: ProjectileState = {
      id: this.nextEntityId++,
      x: this.state.player.x + direction.x * (this.state.player.radius + this.config.projectileRadius + 1),
      y: this.state.player.y + direction.y * (this.state.player.radius + this.config.projectileRadius + 1),
      vx: direction.x * this.config.projectileSpeed / 60,
      vy: direction.y * this.config.projectileSpeed / 60,
      radius: this.config.projectileRadius,
      damage: this.config.projectileDamage,
      ageTicks: 0,
    };
    this.lastAim = clonePoint(aim);
    this.state.projectiles.push(projectile);
    this.fireCooldown = this.config.fireCooldownTicks;
    this.events.push({ type: "shot", tick: this.state.tick, projectileId: projectile.id });
  }

  private moveProjectiles(): void {
    this.projectileStarts.clear();
    this.state.projectiles = this.state.projectiles.filter((projectile) => {
      this.projectileStarts.set(projectile.id, { x: projectile.x, y: projectile.y });
      projectile.x += projectile.vx;
      projectile.y += projectile.vy;
      projectile.ageTicks += 1;
      return projectile.ageTicks <= this.config.projectileLifetimeTicks && this.isInsideArena(projectile, projectile.radius);
    });
  }

  private moveEnemies(): void {
    for (const enemy of this.state.enemies) {
      const toPlayer = normalized(this.state.player.x - enemy.x, this.state.player.y - enemy.y);
      let direction = toPlayer;
      if (enemy.variant === "striker") {
        const sway = Math.sin((this.state.tick + enemy.id * 17) * 0.08) * 0.75;
        direction = normalized(toPlayer.x - toPlayer.y * sway, toPlayer.y + toPlayer.x * sway);
      }
      enemy.x = clamp(enemy.x + direction.x * enemy.speed / 60, enemy.radius, this.config.arena.width - enemy.radius);
      enemy.y = clamp(enemy.y + direction.y * enemy.speed / 60, enemy.radius, this.config.arena.height - enemy.radius);
    }
  }

  private resolveProjectileCollisions(): void {
    const remaining: ProjectileState[] = [];
    for (const projectile of this.state.projectiles) {
      const target = this.state.enemies.find(
        (enemy) => segmentIntersectsCircle(
          this.projectileStarts.get(projectile.id) ?? projectile,
          projectile,
          enemy,
          projectile.radius + enemy.radius,
        ),
      );
      if (!target) {
        remaining.push(projectile);
        continue;
      }
      target.health -= projectile.damage;
      if (target.health > 0) {
        this.events.push({ type: "enemy-hit", tick: this.state.tick, enemyId: target.id, remainingHealth: target.health });
      } else {
        this.state.score += target.scoreValue;
        this.state.enemies = this.state.enemies.filter((enemy) => enemy.id !== target.id);
        this.events.push({ type: "enemy-defeated", tick: this.state.tick, enemyId: target.id, score: this.state.score });
      }
    }
    this.state.projectiles = remaining;
    this.projectileStarts.clear();
  }

  private resolvePlayerContacts(): void {
    if (this.state.player.invulnerableTicks > 0) return;
    const contact = this.state.enemies.find(
      (enemy) => distanceSquared(this.state.player, enemy) <= (this.state.player.radius + enemy.radius) ** 2,
    );
    if (!contact) return;
    this.state.player.health = Math.max(0, this.state.player.health - contact.contactDamage);
    this.state.player.invulnerableTicks = this.config.invulnerabilityTicks;
    this.state.player.hitFlashTicks = 8;
    this.events.push({ type: "player-damaged", tick: this.state.tick, amount: contact.contactDamage, health: this.state.player.health });
  }

  private finishIfDead(): void {
    if (this.state.player.health > 0) return;
    this.state.status = "game-over";
    const terminal: CompletedGameRecord = {
      seed: this.state.seed,
      finalTick: this.state.tick,
      score: this.state.score,
      wave: this.state.wave,
    };
    this.state.terminal = terminal;
    this.events.push({ type: "game-over", tick: this.state.tick, terminal: { ...terminal } });
  }

  private findSpawnPosition(radius: number): Point {
    const minDistance = this.config.spawnRadius + radius;
    const arenaDiagonal = Math.hypot(this.config.arena.width, this.config.arena.height);
    const maxDistance = Math.min(arenaDiagonal, minDistance + 64);
    for (let attempt = 0; attempt < 64; attempt += 1) {
      const angle = this.random.range(0, TAU);
      const distance = this.random.range(minDistance, Math.max(minDistance, maxDistance));
      const point = {
        x: this.state.player.x + Math.cos(angle) * distance,
        y: this.state.player.y + Math.sin(angle) * distance,
      };
      if (this.isInsideArena(point, radius) && distanceSquared(point, this.state.player) >= minDistance ** 2) return point;
    }
    const candidates = [
      { x: radius, y: radius },
      { x: this.config.arena.width - radius, y: radius },
      { x: radius, y: this.config.arena.height - radius },
      { x: this.config.arena.width - radius, y: this.config.arena.height - radius },
    ];
    return candidates.sort((a, b) => distanceSquared(b, this.state.player) - distanceSquared(a, this.state.player))[0];
  }

  private clampPoint(point: Point, radius: number): Point {
    return {
      x: clamp(point.x, radius, this.config.arena.width - radius),
      y: clamp(point.y, radius, this.config.arena.height - radius),
    };
  }

  private isInsideArena(point: Point, radius: number): boolean {
    return point.x >= radius && point.x <= this.config.arena.width - radius && point.y >= radius && point.y <= this.config.arena.height - radius;
  }
}
