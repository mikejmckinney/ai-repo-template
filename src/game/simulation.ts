/**
 * Deterministic, renderer-agnostic game simulation for Vector Siege.
 *
 * All movement is advanced by one fixed tick per call to `step`.  The values
 * exposed as velocities are world-units per second; the simulation applies
 * FIXED_TIMESTEP_MS when integrating them.
 */

export const FIXED_TIMESTEP_MS = 1000 / 60;

const FIXED_TIMESTEP_SECONDS = FIXED_TIMESTEP_MS / 1000;
const DEFAULT_SEED = 0x1a2b3c4d;
const DEFAULT_WIDTH = 960;
const DEFAULT_HEIGHT = 540;
const DEFAULT_SPAWN_RADIUS = 220;
const PLAYER_RADIUS = 14;
const PLAYER_SPEED = 240;
const PLAYER_MAX_HEALTH = 5;
const PLAYER_INVULNERABILITY_TICKS = 45;
const PROJECTILE_RADIUS = 4;
const PROJECTILE_SPEED = 720;
const PROJECTILE_LIFETIME_TICKS = 90;
const FIRE_COOLDOWN_TICKS = 6;

export type GameStatus = "running" | "gameover";

export type EnemyKind = "chaser" | "striker" | "tank";

export interface SimulationInput {
  moveX: number;
  moveY: number;
  aimX: number;
  aimY: number;
  fire: boolean;
  firePressed?: boolean;
}

export interface PlayerState {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  speed: number;
  health: number;
  maxHealth: number;
  invulnerabilityTicks: number;
  fireCooldownTicks: number;
}

export interface EnemyState {
  id: number;
  kind: EnemyKind;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  speed: number;
  health: number;
  maxHealth: number;
  contactDamage: number;
  scoreValue: number;
  /** A deterministic phase used by the striker's lateral movement. */
  phase: number;
}

export interface ProjectileState {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  damage: number;
  remainingTicks: number;
}

export interface ArenaState {
  width: number;
  height: number;
  spawnRadius: number;
}

export interface CompletedRecord {
  seed: number;
  score: number;
  wave: number;
  /** The final fixed simulation tick. */
  tick: number;
  /** Alias that makes the recorded terminal tick explicit to scene code. */
  finalTick: number;
}

export interface GameState {
  status: GameStatus;
  score: number;
  wave: number;
  tick: number;
  seed: number;
  completedRecord: CompletedRecord | null;
  player: PlayerState;
  enemies: EnemyState[];
  projectiles: ProjectileState[];
  arena: ArenaState;
  /** Convenience mirrors of arena dimensions for renderer code. */
  width: number;
  height: number;
  spawnRadius: number;
}

export type SimulationEvent =
  | {
      type: "shot";
      tick: number;
      projectileId: number;
      x: number;
      y: number;
      aimX: number;
      aimY: number;
    }
  | {
      type: "enemy-hit";
      tick: number;
      enemyId: number;
      projectileId: number;
      damage: number;
      health: number;
      remainingHealth: number;
    }
  | {
      type: "enemy-defeated";
      tick: number;
      enemyId: number;
      kind: EnemyKind;
      scoreAward: number;
      score: number;
    }
  | {
      type: "player-hit";
      tick: number;
      enemyId: number;
      damage: number;
      health: number;
      invulnerabilityTicks: number;
    }
  | {
      type: "wave-start";
      tick: number;
      wave: number;
      enemyCount: number;
    }
  | {
      type: "game-over";
      tick: number;
      seed: number;
      wave: number;
      score: number;
    };

export interface SimulationOptions {
  seed?: number;
  width?: number;
  height?: number;
  spawnRadius?: number;
}

interface Point {
  x: number;
  y: number;
}

interface EnemyTuning {
  radius: number;
  speed: number;
  maxHealth: number;
  contactDamage: number;
  scoreValue: number;
}

/** Small xorshift generator; no platform or global random state is involved. */
class SeededRandom {
  private value: number;

  public constructor(seed: number) {
    // A zero xorshift state would remain zero forever.  Keep state.seed equal
    // to the caller's seed while using a non-zero internal state in that case.
    this.value = (seed >>> 0) || 0x9e3779b9;
  }

  public next(): number {
    let value = this.value;
    value ^= value << 13;
    value ^= value >>> 17;
    value ^= value << 5;
    this.value = value >>> 0;
    return this.value / 0x100000000;
  }
}

function finiteOr(value: number | undefined, fallback: number): number {
  return value !== undefined && Number.isFinite(value) ? value : fallback;
}

function normalizedSeed(seed: number | undefined): number {
  const value = finiteOr(seed, DEFAULT_SEED);
  return Math.trunc(value) >>> 0;
}

function dimensionOr(value: number | undefined, fallback: number): number {
  const candidate = finiteOr(value, fallback);
  return candidate > 2 ? candidate : fallback;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function distanceSquared(a: Point, b: Point): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return dx * dx + dy * dy;
}

function normalize(x: number, y: number, fallbackX = 1, fallbackY = 0): Point {
  const length = Math.hypot(x, y);
  if (length < 0.000001) {
    return { x: fallbackX, y: fallbackY };
  }
  return { x: x / length, y: y / length };
}

function segmentIntersectsCircle(
  start: Point,
  end: Point,
  center: Point,
  radius: number,
): boolean {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const segmentLengthSquared = dx * dx + dy * dy;

  if (segmentLengthSquared < 0.000001) {
    return distanceSquared(start, center) <= radius * radius;
  }

  const projection =
    ((center.x - start.x) * dx + (center.y - start.y) * dy) /
    segmentLengthSquared;
  const t = clamp(projection, 0, 1);
  const closest = {
    x: start.x + dx * t,
    y: start.y + dy * t,
  };
  return distanceSquared(closest, center) <= radius * radius;
}

export class Simulation {
  private readonly width: number;
  private readonly height: number;
  private readonly spawnRadius: number;
  private random: SeededRandom;
  private currentSeed: number;
  private nextEnemyId = 1;
  private nextProjectileId = 1;
  private pendingEvents: SimulationEvent[] = [];
  private stateValue!: GameState;

  public constructor(options: SimulationOptions = {}) {
    this.width = dimensionOr(options.width, DEFAULT_WIDTH);
    this.height = dimensionOr(options.height, DEFAULT_HEIGHT);
    this.spawnRadius = Math.max(0, finiteOr(options.spawnRadius, DEFAULT_SPAWN_RADIUS));
    this.currentSeed = normalizedSeed(options.seed);
    this.random = new SeededRandom(this.currentSeed);
    this.reset(this.currentSeed);
  }

  public get state(): GameState {
    return this.stateValue;
  }

  public reset(seed?: number): void {
    this.currentSeed = seed === undefined ? this.currentSeed : normalizedSeed(seed);
    this.random = new SeededRandom(this.currentSeed);
    this.nextEnemyId = 1;
    this.nextProjectileId = 1;
    this.pendingEvents = [];

    const player: PlayerState = {
      x: this.width / 2,
      y: this.height / 2,
      vx: 0,
      vy: 0,
      radius: PLAYER_RADIUS,
      speed: PLAYER_SPEED,
      health: PLAYER_MAX_HEALTH,
      maxHealth: PLAYER_MAX_HEALTH,
      invulnerabilityTicks: 0,
      fireCooldownTicks: 0,
    };
    const arena: ArenaState = {
      width: this.width,
      height: this.height,
      spawnRadius: this.spawnRadius,
    };

    this.stateValue = {
      status: "running",
      score: 0,
      wave: 1,
      tick: 0,
      seed: this.currentSeed,
      completedRecord: null,
      player,
      enemies: [],
      projectiles: [],
      arena,
      width: this.width,
      height: this.height,
      spawnRadius: this.spawnRadius,
    };

    this.spawnWave();
  }

  public step(input: SimulationInput): SimulationEvent[] {
    const events = this.pendingEvents.splice(0, this.pendingEvents.length);
    if (this.stateValue.status === "gameover") {
      return events;
    }

    this.stateValue.tick += 1;
    this.updatePlayer(input);

    const wantsToFire = input.fire || input.firePressed === true;
    if (wantsToFire && this.stateValue.player.fireCooldownTicks === 0) {
      this.fire(input, events);
    }

    this.updateEnemies(events);
    if (this.stateValue.status === "running") {
      this.updateProjectiles(events);
    }

    if (this.stateValue.status === "running" && this.stateValue.enemies.length === 0) {
      this.stateValue.wave += 1;
      this.spawnWave(events);
    }

    return events;
  }

  private updatePlayer(input: SimulationInput): void {
    const player = this.stateValue.player;
    const moveX = finiteOr(input.moveX, 0);
    const moveY = finiteOr(input.moveY, 0);
    const direction = normalize(moveX, moveY, 0, 0);
    const moveLength = Math.min(1, Math.hypot(moveX, moveY));
    player.vx = direction.x * player.speed * moveLength;
    player.vy = direction.y * player.speed * moveLength;
    player.x = clamp(
      player.x + player.vx * FIXED_TIMESTEP_SECONDS,
      player.radius,
      this.width - player.radius,
    );
    player.y = clamp(
      player.y + player.vy * FIXED_TIMESTEP_SECONDS,
      player.radius,
      this.height - player.radius,
    );
    player.invulnerabilityTicks = Math.max(0, player.invulnerabilityTicks - 1);
    player.fireCooldownTicks = Math.max(0, player.fireCooldownTicks - 1);
  }

  private fire(input: SimulationInput, events: SimulationEvent[]): void {
    const player = this.stateValue.player;
    const aimX = finiteOr(input.aimX, player.x + 1);
    const aimY = finiteOr(input.aimY, player.y);
    const direction = normalize(aimX - player.x, aimY - player.y);
    const spawnDistance = player.radius + PROJECTILE_RADIUS + 2;
    const projectile: ProjectileState = {
      id: this.nextProjectileId,
      x: player.x + direction.x * spawnDistance,
      y: player.y + direction.y * spawnDistance,
      vx: direction.x * PROJECTILE_SPEED,
      vy: direction.y * PROJECTILE_SPEED,
      radius: PROJECTILE_RADIUS,
      damage: 1,
      remainingTicks: PROJECTILE_LIFETIME_TICKS,
    };
    this.nextProjectileId += 1;
    this.stateValue.projectiles.push(projectile);
    player.fireCooldownTicks = FIRE_COOLDOWN_TICKS;
    events.push({
      type: "shot",
      tick: this.stateValue.tick,
      projectileId: projectile.id,
      x: projectile.x,
      y: projectile.y,
      aimX,
      aimY,
    });
  }

  private updateEnemies(events: SimulationEvent[]): void {
    const player = this.stateValue.player;
    for (const enemy of this.stateValue.enemies) {
      const toPlayer = {
        x: player.x - enemy.x,
        y: player.y - enemy.y,
      };
      const direct = normalize(toPlayer.x, toPlayer.y);
      let direction = direct;

      if (enemy.kind === "striker") {
        const perpendicular = { x: -direct.y, y: direct.x };
        const lateralAmount = Math.sin(this.stateValue.tick * 0.11 + enemy.phase) * 0.8;
        direction = normalize(
          direct.x + perpendicular.x * lateralAmount,
          direct.y + perpendicular.y * lateralAmount,
        );
      }

      enemy.vx = direction.x * enemy.speed;
      enemy.vy = direction.y * enemy.speed;
      enemy.x = clamp(
        enemy.x + enemy.vx * FIXED_TIMESTEP_SECONDS,
        enemy.radius,
        this.width - enemy.radius,
      );
      enemy.y = clamp(
        enemy.y + enemy.vy * FIXED_TIMESTEP_SECONDS,
        enemy.radius,
        this.height - enemy.radius,
      );

      if (
        distanceSquared(enemy, player) <=
        (enemy.radius + player.radius) * (enemy.radius + player.radius)
      ) {
        this.damagePlayer(enemy, events);
        if (this.stateValue.status === "gameover") {
          return;
        }
      }
    }
  }

  private damagePlayer(enemy: EnemyState, events: SimulationEvent[]): void {
    const player = this.stateValue.player;
    if (player.invulnerabilityTicks > 0) {
      return;
    }

    player.health = Math.max(0, player.health - enemy.contactDamage);
    player.invulnerabilityTicks = PLAYER_INVULNERABILITY_TICKS;
    events.push({
      type: "player-hit",
      tick: this.stateValue.tick,
      enemyId: enemy.id,
      damage: enemy.contactDamage,
      health: player.health,
      invulnerabilityTicks: player.invulnerabilityTicks,
    });

    if (player.health <= 0) {
      this.stateValue.status = "gameover";
      const record: CompletedRecord = {
        seed: this.stateValue.seed,
        score: this.stateValue.score,
        wave: this.stateValue.wave,
        tick: this.stateValue.tick,
        finalTick: this.stateValue.tick,
      };
      this.stateValue.completedRecord = record;
      events.push({
        type: "game-over",
        tick: this.stateValue.tick,
        seed: record.seed,
        wave: record.wave,
        score: record.score,
      });
    }
  }

  private updateProjectiles(events: SimulationEvent[]): void {
    const projectiles: ProjectileState[] = [];

    for (const projectile of this.stateValue.projectiles) {
      const start = { x: projectile.x, y: projectile.y };
      projectile.x += projectile.vx * FIXED_TIMESTEP_SECONDS;
      projectile.y += projectile.vy * FIXED_TIMESTEP_SECONDS;
      projectile.remainingTicks -= 1;

      let hitEnemy = false;
      for (let enemyIndex = 0; enemyIndex < this.stateValue.enemies.length; enemyIndex += 1) {
        const enemy = this.stateValue.enemies[enemyIndex];
        const hitRadius = projectile.radius + enemy.radius;
        if (
          segmentIntersectsCircle(
            start,
            { x: projectile.x, y: projectile.y },
            enemy,
            hitRadius,
          )
        ) {
          hitEnemy = true;
          enemy.health = Math.max(0, enemy.health - projectile.damage);
          events.push({
            type: "enemy-hit",
            tick: this.stateValue.tick,
            enemyId: enemy.id,
            projectileId: projectile.id,
            damage: projectile.damage,
            health: enemy.health,
            remainingHealth: enemy.health,
          });

          if (enemy.health <= 0) {
            this.stateValue.score += enemy.scoreValue;
            events.push({
              type: "enemy-defeated",
              tick: this.stateValue.tick,
              enemyId: enemy.id,
              kind: enemy.kind,
              scoreAward: enemy.scoreValue,
              score: this.stateValue.score,
            });
            this.stateValue.enemies.splice(enemyIndex, 1);
          }
          break;
        }
      }

      if (hitEnemy) {
        continue;
      }

      const outsideArena =
        projectile.x < -projectile.radius ||
        projectile.x > this.width + projectile.radius ||
        projectile.y < -projectile.radius ||
        projectile.y > this.height + projectile.radius;
      if (outsideArena || projectile.remainingTicks <= 0) {
        continue;
      }
      projectiles.push(projectile);
    }

    this.stateValue.projectiles = projectiles;
  }

  private spawnWave(events: SimulationEvent[] = this.pendingEvents): void {
    const wave = this.stateValue.wave;
    // Three enemies in wave one keeps the opening readable while guaranteeing
    // both of the fast enemy behaviours are present from the start.
    const enemyCount = wave === 1 ? 3 : Math.min(14, 3 + wave);

    for (let index = 0; index < enemyCount; index += 1) {
      const kind = this.kindForWave(wave, index);
      const tuning = this.tuningFor(kind, wave);
      const position = this.spawnPosition(tuning.radius);
      const enemy: EnemyState = {
        id: this.nextEnemyId,
        kind,
        x: position.x,
        y: position.y,
        vx: 0,
        vy: 0,
        radius: tuning.radius,
        speed: tuning.speed,
        health: tuning.maxHealth,
        maxHealth: tuning.maxHealth,
        contactDamage: tuning.contactDamage,
        scoreValue: tuning.scoreValue,
        phase: this.random.next() * Math.PI * 2,
      };
      this.nextEnemyId += 1;
      this.stateValue.enemies.push(enemy);
    }

    events.push({
      type: "wave-start",
      tick: this.stateValue.tick,
      wave,
      enemyCount,
    });
  }

  private kindForWave(wave: number, index: number): EnemyKind {
    if (wave === 1) {
      return index === 1 ? "striker" : "chaser";
    }
    if (wave >= 3 && index === Math.min(14, 3 + wave) - 1) {
      return "tank";
    }
    return index % 3 === 1 ? "striker" : "chaser";
  }

  private tuningFor(kind: EnemyKind, wave: number): EnemyTuning {
    switch (kind) {
      case "chaser":
        return {
          radius: 16,
          speed: 62 + wave * 4,
          maxHealth: 1 + Math.floor((wave - 1) / 3),
          contactDamage: 1,
          scoreValue: 100 * wave,
        };
      case "striker":
        return {
          radius: 14,
          speed: 48 + wave * 3,
          maxHealth: 2 + Math.floor((wave - 1) / 2),
          contactDamage: 1,
          scoreValue: 150 * wave,
        };
      case "tank":
        return {
          radius: 22,
          speed: 28 + wave * 2,
          maxHealth: 6 + wave,
          contactDamage: 2,
          scoreValue: 300 * wave,
        };
    }
  }

  private spawnPosition(enemyRadius: number): Point {
    const player = this.stateValue.player;
    const margin = enemyRadius + 4;
    const halfWidth = Math.max(1, this.width / 2 - margin);
    const halfHeight = Math.max(1, this.height / 2 - margin);
    const baseAngle = this.random.next() * Math.PI * 2;
    const candidates: Point[] = [];

    // Sample a deterministic ring of directions.  The first valid candidate
    // is outside the requested radius; a farthest-edge fallback is used only
    // when a caller requests a radius larger than this arena can contain.
    for (let attempt = 0; attempt < 24; attempt += 1) {
      const angle = baseAngle + (attempt * Math.PI * 2) / 24;
      const direction = { x: Math.cos(angle), y: Math.sin(angle) };
      const horizontalDistance =
        Math.abs(direction.x) < 0.000001 ? Number.POSITIVE_INFINITY : halfWidth / Math.abs(direction.x);
      const verticalDistance =
        Math.abs(direction.y) < 0.000001 ? Number.POSITIVE_INFINITY : halfHeight / Math.abs(direction.y);
      const boundaryDistance = Math.min(horizontalDistance, verticalDistance);
      const candidate = {
        x: clamp(player.x + direction.x * boundaryDistance, margin, this.width - margin),
        y: clamp(player.y + direction.y * boundaryDistance, margin, this.height - margin),
      };
      candidates.push(candidate);
      if (distanceSquared(candidate, player) >= this.spawnRadius * this.spawnRadius) {
        return candidate;
      }
    }

    let farthest = candidates[0] ?? { x: this.width - margin, y: this.height / 2 };
    for (const candidate of candidates) {
      if (distanceSquared(candidate, player) > distanceSquared(farthest, player)) {
        farthest = candidate;
      }
    }
    return farthest;
  }
}

export default Simulation;

