export type Seed = number | string;

export type GamePhase = "menu" | "running" | "paused" | "game-over";

export type EnemyKind = "chaser" | "striker" | "tank";

export interface StepInput {
  up: boolean;
  down: boolean;
  left: boolean;
  right: boolean;
  fire: boolean;
  aimX: number;
  aimY: number;
}

export interface ArenaBounds {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface SimulationConfig {
  width?: number;
  height?: number;
  arena?: ArenaBounds;
  seed?: Seed;
  playerHealth?: number;
  spawnRadius?: number;
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

export interface ProjectileState {
  id: number;
  x: number;
  y: number;
  radius: number;
  velocityX: number;
  velocityY: number;
  damage: number;
  remainingTicks: number;
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
  phase: number;
}

export interface CompletedGameRecord {
  seed: string;
  finalTick: number;
  score: number;
  wave: number;
}

export type SimulationEvent =
  | { type: "shot-fired"; projectileId: number; x: number; y: number }
  | { type: "enemy-hit"; enemyId: number; x: number; y: number }
  | { type: "enemy-defeated"; enemyId: number; kind: EnemyKind; x: number; y: number; score: number }
  | { type: "player-hit"; health: number; x: number; y: number }
  | { type: "wave-start"; wave: number; count: number }
  | { type: "game-over"; record: CompletedGameRecord };

export interface SimulationSnapshot {
  phase: GamePhase;
  seed: string;
  tick: number;
  score: number;
  wave: number;
  arena: ArenaBounds;
  player: PlayerState;
  projectiles: ProjectileState[];
  enemies: EnemyState[];
  completedGame: CompletedGameRecord | null;
}

export interface SimulationController {
  start(): void;
  pause(): void;
  resume(): void;
  restart(seed?: Seed): void;
  step(input: StepInput): void;
  snapshot(): SimulationSnapshot;
  drainEvents(): SimulationEvent[];
}
