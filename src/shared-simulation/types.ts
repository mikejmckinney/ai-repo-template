export type EnemyVariant = "chaser" | "striker" | "tank";
export type SimulationStatus = "menu" | "running" | "paused" | "game-over";

export interface Point {
  x: number;
  y: number;
}

export interface ArenaSize {
  width: number;
  height: number;
}

export type ControlKey =
  | "w"
  | "a"
  | "s"
  | "d"
  | "arrowup"
  | "arrowleft"
  | "arrowdown"
  | "arrowright"
  | "space";

export interface PointerInput extends Point {
  down?: boolean;
}

export interface SimulationInput {
  moveX?: number;
  moveY?: number;
  keys?: Partial<Record<ControlKey, boolean>>;
  aim?: Point;
  pointer?: PointerInput;
  fire?: boolean;
}

export interface EnemyStatOverride {
  health?: number;
  speed?: number;
  radius?: number;
  contactDamage?: number;
  scoreValue?: number;
}

export interface SimulationConfig {
  seed?: number;
  arena?: ArenaSize;
  playerStart?: Point;
  playerRadius?: number;
  playerSpeed?: number;
  playerMaxHealth?: number;
  invulnerabilityTicks?: number;
  projectileSpeed?: number;
  projectileRadius?: number;
  projectileDamage?: number;
  projectileLifetimeTicks?: number;
  fireCooldownTicks?: number;
  spawnRadius?: number;
  initialEnemiesPerWave?: number;
  waveEnemyGrowth?: number;
  maxCatchUpSteps?: number;
  enemyStats?: Partial<Record<EnemyVariant, EnemyStatOverride>>;
}

export interface EnemyState extends Point {
  id: number;
  variant: EnemyVariant;
  radius: number;
  health: number;
  maxHealth: number;
  speed: number;
  contactDamage: number;
  scoreValue: number;
}

export interface ProjectileState extends Point {
  id: number;
  vx: number;
  vy: number;
  radius: number;
  damage: number;
  ageTicks: number;
}

export interface PlayerState extends Point {
  radius: number;
  health: number;
  maxHealth: number;
  invulnerableTicks: number;
  hitFlashTicks: number;
}

export interface CompletedGameRecord {
  seed: number;
  finalTick: number;
  score: number;
  wave: number;
}

export interface SimulationState {
  status: SimulationStatus;
  seed: number;
  tick: number;
  wave: number;
  score: number;
  player: PlayerState;
  projectiles: ProjectileState[];
  enemies: EnemyState[];
  terminal: CompletedGameRecord | null;
}

export type SimulationEvent =
  | { type: "started"; tick: number; wave: number }
  | { type: "restarted"; tick: number; wave: number }
  | { type: "paused"; tick: number }
  | { type: "resumed"; tick: number }
  | { type: "wave-started"; tick: number; wave: number; count: number }
  | { type: "enemy-spawned"; tick: number; enemyId: number; variant: EnemyVariant }
  | { type: "shot"; tick: number; projectileId: number }
  | { type: "enemy-hit"; tick: number; enemyId: number; remainingHealth: number }
  | { type: "enemy-defeated"; tick: number; enemyId: number; score: number }
  | { type: "player-damaged"; tick: number; amount: number; health: number }
  | { type: "game-over"; tick: number; terminal: CompletedGameRecord };

export interface StartOptions {
  spawnWave?: boolean;
}
