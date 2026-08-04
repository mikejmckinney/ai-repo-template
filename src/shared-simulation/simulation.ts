export const TICKS_PER_SECOND = 60;
export const FIXED_STEP_MS = 1000 / TICKS_PER_SECOND;

export const ARENA_BOUNDS = {
  left: 42,
  right: 1238,
  top: 104,
  bottom: 678,
};

export const PLAYER_START = { x: 640, y: 405 };
export const DEFAULT_SEED = "vector-siege-stage-1";
export const PLAYER_RADIUS = 24;
export const PLAYER_SPEED = 270;
export const INVULNERABILITY_TICKS = 75;
export const DEFAULT_ENEMY_SPAWN_RADIUS = 390;

export type GameStatus = "menu" | "running" | "paused" | "game-over";
export type EnemyKind = "chaser" | "striker" | "tank";

export interface SimulationInput {
  up?: boolean;
  down?: boolean;
  left?: boolean;
  right?: boolean;
  fire?: boolean;
  aimX?: number;
  aimY?: number;
}

export interface SimulationConfig {
  enemySpawnRadius?: number;
}

export interface PlayerState {
  x: number;
  y: number;
  radius: number;
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
  phase: number;
  flashTicks: number;
}

export interface ProjectileState {
  id: number;
  x: number;
  y: number;
  dx: number;
  dy: number;
  speed: number;
  radius: number;
  damage: number;
  ttl: number;
}

export interface CompletionRecord {
  seed: string;
  finalTick: number;
  score: number;
  wave: number;
}

export type SimulationEvent =
  | { type: "shot"; x: number; y: number; dx: number; dy: number }
  | { type: "enemy-hit"; id: number; kind: EnemyKind; x: number; y: number; health: number }
  | { type: "enemy-defeated"; id: number; kind: EnemyKind; x: number; y: number; points: number }
  | { type: "player-hit"; x: number; y: number; health: number }
  | { type: "wave-start"; wave: number; count: number }
  | { type: "game-over"; completion: CompletionRecord };

export interface SimulationState {
  status: GameStatus;
  seed: string;
  rngState: number;
  tick: number;
  wave: number;
  score: number;
  kills: number;
  health: number;
  maxHealth: number;
  invulnerableTicks: number;
  fireCooldown: number;
  enemySpawnRadius: number;
  player: PlayerState;
  enemies: EnemyState[];
  projectiles: ProjectileState[];
  nextEnemyId: number;
  nextProjectileId: number;
  waveTarget: number;
  waveEnemiesDefeated: number;
  completion: CompletionRecord | null;
  lastEvents: SimulationEvent[];
}

interface EnemyStats {
  radius: number;
  health: number;
  speed: number;
  points: number;
}

const ENEMY_STATS: Record<EnemyKind, EnemyStats> = {
  chaser: { radius: 23, health: 1, speed: 108, points: 100 },
  striker: { radius: 25, health: 2, speed: 84, points: 150 },
  tank: { radius: 31, health: 5, speed: 48, points: 250 },
};

const PLAYER_DAMAGE = 1;
const PROJECTILE_SPEED = 760;
const PROJECTILE_TTL = 100;
const FIRE_COOLDOWN_TICKS = 8;

function hashSeed(seed: string): number {
  let hash = 2166136261;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0 || 0x9e3779b9;
}

function random(state: SimulationState): number {
  let value = state.rngState || 0x9e3779b9;
  value ^= value << 13;
  value ^= value >>> 17;
  value ^= value << 5;
  state.rngState = value >>> 0;
  return state.rngState / 0x100000000;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function distanceSquared(ax: number, ay: number, bx: number, by: number): number {
  const dx = ax - bx;
  const dy = ay - by;
  return dx * dx + dy * dy;
}

function enemyKindFor(wave: number, index: number, state: SimulationState): EnemyKind {
  if (wave === 1 && index === 0) return "chaser";
  const roll = random(state);
  if (wave >= 3 && roll > 0.78) return "tank";
  if (roll > 0.46) return "striker";
  return "chaser";
}

function waveSize(wave: number): number {
  return Math.min(14, 3 + wave * 2);
}

function rayDistanceToArena(state: SimulationState, angle: number, radius: number): number {
  const dx = Math.cos(angle);
  const dy = Math.sin(angle);
  const distances: number[] = [];
  if (dx > 0) distances.push((ARENA_BOUNDS.right - radius - state.player.x) / dx);
  if (dx < 0) distances.push((ARENA_BOUNDS.left + radius - state.player.x) / dx);
  if (dy > 0) distances.push((ARENA_BOUNDS.bottom - radius - state.player.y) / dy);
  if (dy < 0) distances.push((ARENA_BOUNDS.top + radius - state.player.y) / dy);
  return Math.max(0, Math.min(...distances.filter((distance) => distance >= 0)));
}

function spawnPosition(state: SimulationState, angle: number, radius: number): { x: number; y: number } {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const candidateAngle = attempt === 0 ? angle : random(state) * Math.PI * 2;
    const maxDistance = rayDistanceToArena(state, candidateAngle, radius);
    if (maxDistance < state.enemySpawnRadius) continue;
    const extraDistance = Math.min(110, Math.max(0, maxDistance - state.enemySpawnRadius));
    const distance = state.enemySpawnRadius + random(state) * extraDistance;
    return {
      x: state.player.x + Math.cos(candidateAngle) * distance,
      y: state.player.y + Math.sin(candidateAngle) * distance,
    };
  }

  const fallbackAngle = state.player.x <= (ARENA_BOUNDS.left + ARENA_BOUNDS.right) / 2 ? 0 : Math.PI;
  const fallbackDistance = Math.max(state.enemySpawnRadius, rayDistanceToArena(state, fallbackAngle, radius) - 1);
  return {
    x: state.player.x + Math.cos(fallbackAngle) * fallbackDistance,
    y: state.player.y + Math.sin(fallbackAngle) * fallbackDistance,
  };
}

function spawnWave(state: SimulationState, events: SimulationEvent[]): void {
  const count = waveSize(state.wave);
  state.waveTarget = count;
  state.waveEnemiesDefeated = 0;

  for (let index = 0; index < count; index += 1) {
    const kind = enemyKindFor(state.wave, index, state);
    const angle = state.wave === 1 && index === 0 ? 0 : random(state) * Math.PI * 2;
    const stats = ENEMY_STATS[kind];
    const position = spawnPosition(state, angle, stats.radius);
    const health = stats.health + Math.floor((state.wave - 1) / 4);
    state.enemies.push({
      id: state.nextEnemyId,
      kind,
      x: position.x,
      y: position.y,
      radius: stats.radius,
      health,
      maxHealth: health,
      speed: stats.speed + Math.min(34, (state.wave - 1) * 4),
      phase: random(state) * Math.PI * 2,
      flashTicks: 0,
    });
    state.nextEnemyId += 1;
  }

  events.push({ type: "wave-start", wave: state.wave, count });
}

function makeState(seed: string, status: GameStatus, config: SimulationConfig): SimulationState {
  return {
    status,
    seed,
    rngState: hashSeed(seed),
    tick: 0,
    wave: 1,
    score: 0,
    kills: 0,
    health: 3,
    maxHealth: 3,
    invulnerableTicks: 0,
    fireCooldown: 0,
    enemySpawnRadius: Math.max(300, config.enemySpawnRadius ?? DEFAULT_ENEMY_SPAWN_RADIUS),
    player: { ...PLAYER_START, radius: PLAYER_RADIUS },
    enemies: [],
    projectiles: [],
    nextEnemyId: 1,
    nextProjectileId: 1,
    waveTarget: 0,
    waveEnemiesDefeated: 0,
    completion: null,
    lastEvents: [],
  };
}

export function createSimulation(seed = DEFAULT_SEED, config: SimulationConfig = {}): SimulationState {
  return makeState(seed, "menu", config);
}

export function startSimulation(seed = DEFAULT_SEED, config: SimulationConfig = {}): SimulationState {
  const state = makeState(seed, "running", config);
  const events: SimulationEvent[] = [];
  spawnWave(state, events);
  state.lastEvents = events;
  return state;
}

export function restartSimulation(
  state: SimulationState,
  seed = state.seed,
  config: SimulationConfig = { enemySpawnRadius: state.enemySpawnRadius },
): SimulationState {
  return startSimulation(seed, config);
}

export function pauseSimulation(state: SimulationState): boolean {
  if (state.status !== "running") return false;
  state.status = "paused";
  return true;
}

export function resumeSimulation(state: SimulationState): boolean {
  if (state.status !== "paused") return false;
  state.status = "running";
  return true;
}

export function setPlayerPosition(state: SimulationState, x: number, y: number): void {
  state.player.x = clamp(x, ARENA_BOUNDS.left + state.player.radius, ARENA_BOUNDS.right - state.player.radius);
  state.player.y = clamp(y, ARENA_BOUNDS.top + state.player.radius, ARENA_BOUNDS.bottom - state.player.radius);
}

export function damageSimulation(state: SimulationState, amount = PLAYER_DAMAGE): SimulationEvent[] {
  const events: SimulationEvent[] = [];
  applyDamage(state, amount, events);
  state.lastEvents = events;
  return events;
}

function applyDamage(state: SimulationState, amount: number, events: SimulationEvent[]): void {
  if (state.status !== "running" || state.invulnerableTicks > 0) return;
  state.health = Math.max(0, state.health - amount);
  state.invulnerableTicks = INVULNERABILITY_TICKS;
  events.push({ type: "player-hit", x: state.player.x, y: state.player.y, health: state.health });

  if (state.health === 0) {
    state.status = "game-over";
    state.completion = {
      seed: state.seed,
      finalTick: state.tick,
      score: state.score,
      wave: state.wave,
    };
    events.push({ type: "game-over", completion: state.completion });
  }
}

function movePlayer(state: SimulationState, input: SimulationInput): void {
  let x = 0;
  let y = 0;
  if (input.left) x -= 1;
  if (input.right) x += 1;
  if (input.up) y -= 1;
  if (input.down) y += 1;
  const length = Math.hypot(x, y);
  if (length > 0) {
    const step = (PLAYER_SPEED / TICKS_PER_SECOND) / length;
    state.player.x += x * step;
    state.player.y += y * step;
  }
  setPlayerPosition(state, state.player.x, state.player.y);
}

function fireProjectile(state: SimulationState, input: SimulationInput, events: SimulationEvent[]): void {
  if (!input.fire || state.fireCooldown > 0) return;
  const aimX = input.aimX ?? state.player.x + 1;
  const aimY = input.aimY ?? state.player.y;
  let dx = aimX - state.player.x;
  let dy = aimY - state.player.y;
  const length = Math.hypot(dx, dy);
  if (length < 0.001) {
    dx = 1;
    dy = 0;
  } else {
    dx /= length;
    dy /= length;
  }
  const projectile: ProjectileState = {
    id: state.nextProjectileId,
    x: state.player.x + dx * (state.player.radius + 5),
    y: state.player.y + dy * (state.player.radius + 5),
    dx,
    dy,
    speed: PROJECTILE_SPEED,
    radius: 5,
    damage: 1,
    ttl: PROJECTILE_TTL,
  };
  state.nextProjectileId += 1;
  state.projectiles.push(projectile);
  state.fireCooldown = FIRE_COOLDOWN_TICKS;
  events.push({ type: "shot", x: projectile.x, y: projectile.y, dx, dy });
}

function moveEnemies(state: SimulationState, events: SimulationEvent[]): void {
  for (const enemy of state.enemies) {
    const dx = state.player.x - enemy.x;
    const dy = state.player.y - enemy.y;
    const distance = Math.max(0.001, Math.hypot(dx, dy));
    let directionX = dx / distance;
    let directionY = dy / distance;

    if (enemy.kind === "striker") {
      const orbit = Math.sin(state.tick * 0.055 + enemy.phase) * 0.62;
      const rotatedX = directionX * Math.cos(orbit) - directionY * Math.sin(orbit);
      const rotatedY = directionX * Math.sin(orbit) + directionY * Math.cos(orbit);
      directionX = rotatedX;
      directionY = rotatedY;
    }

    const step = enemy.speed / TICKS_PER_SECOND;
    enemy.x = clamp(enemy.x + directionX * step, ARENA_BOUNDS.left + enemy.radius, ARENA_BOUNDS.right - enemy.radius);
    enemy.y = clamp(enemy.y + directionY * step, ARENA_BOUNDS.top + enemy.radius, ARENA_BOUNDS.bottom - enemy.radius);
    if (enemy.flashTicks > 0) enemy.flashTicks -= 1;

    const contactDistance = state.player.radius + enemy.radius - 3;
    if (distanceSquared(enemy.x, enemy.y, state.player.x, state.player.y) <= contactDistance * contactDistance) {
      applyDamage(state, 1, events);
      const pushDistance = contactDistance + 8;
      enemy.x = clamp(state.player.x - directionX * pushDistance, ARENA_BOUNDS.left + enemy.radius, ARENA_BOUNDS.right - enemy.radius);
      enemy.y = clamp(state.player.y - directionY * pushDistance, ARENA_BOUNDS.top + enemy.radius, ARENA_BOUNDS.bottom - enemy.radius);
    }
  }
}

function moveProjectiles(state: SimulationState, events: SimulationEvent[]): void {
  const remaining: ProjectileState[] = [];
  for (const projectile of state.projectiles) {
    projectile.x += (projectile.dx * projectile.speed) / TICKS_PER_SECOND;
    projectile.y += (projectile.dy * projectile.speed) / TICKS_PER_SECOND;
    projectile.ttl -= 1;
    if (
      projectile.ttl <= 0 ||
      projectile.x < ARENA_BOUNDS.left ||
      projectile.x > ARENA_BOUNDS.right ||
      projectile.y < ARENA_BOUNDS.top ||
      projectile.y > ARENA_BOUNDS.bottom
    ) {
      continue;
    }

    let hit = false;
    for (const enemy of state.enemies) {
      const collisionRadius = projectile.radius + enemy.radius;
      if (distanceSquared(projectile.x, projectile.y, enemy.x, enemy.y) > collisionRadius * collisionRadius) continue;
      enemy.health -= projectile.damage;
      enemy.flashTicks = 7;
      events.push({ type: "enemy-hit", id: enemy.id, kind: enemy.kind, x: enemy.x, y: enemy.y, health: enemy.health });
      hit = true;

      if (enemy.health <= 0) {
        const points = ENEMY_STATS[enemy.kind].points;
        state.score += points;
        state.kills += 1;
        state.waveEnemiesDefeated += 1;
        events.push({ type: "enemy-defeated", id: enemy.id, kind: enemy.kind, x: enemy.x, y: enemy.y, points });
        state.enemies = state.enemies.filter((candidate) => candidate.id !== enemy.id);
      }
      break;
    }
    if (!hit) remaining.push(projectile);
  }
  state.projectiles = remaining;
}

function maybeStartNextWave(state: SimulationState, events: SimulationEvent[]): void {
  if (state.status !== "running" || state.enemies.length > 0) return;
  state.wave += 1;
  spawnWave(state, events);
}

export function stepSimulation(state: SimulationState, input: SimulationInput = {}): SimulationEvent[] {
  const events: SimulationEvent[] = [];
  if (state.status !== "running") {
    state.lastEvents = events;
    return events;
  }

  state.tick += 1;
  if (state.invulnerableTicks > 0) state.invulnerableTicks -= 1;
  if (state.fireCooldown > 0) state.fireCooldown -= 1;

  movePlayer(state, input);
  fireProjectile(state, input, events);
  moveProjectiles(state, events);
  if (state.status === "running") moveEnemies(state, events);
  maybeStartNextWave(state, events);

  state.lastEvents = events;
  return events;
}

export function snapshotSimulation(state: SimulationState): SimulationState {
  return JSON.parse(JSON.stringify(state)) as SimulationState;
}
