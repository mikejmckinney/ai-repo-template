export const GAME_WIDTH = 1280;
export const GAME_HEIGHT = 720;
export const FIXED_STEP_MS = 1000 / 60;
export const DEFAULT_SEED = "vector-siege-stage-1";
export const ASSET_ROOT = "/benchmark-assets/vector-siege";

export const COLORS = {
  background: 0x08111f,
  accent: 0x49dcb1,
  danger: 0xff4f78,
  highlight: 0xf6c453,
  muted: 0x61728b,
  white: 0xf4f7fb,
};

export const UI_SELECTORS = {
  status: "game-status",
  score: "score-value",
  wave: "wave-value",
  health: "health-value",
  highScore: "high-score-value",
  seed: "seed-value",
  start: "start-mission",
  pause: "pause-game",
  resume: "resume-game",
  mute: "mute-audio",
  restart: "restart-game",
  musicVolume: "music-volume",
  effectsVolume: "effects-volume",
  menu: "menu-panel",
  hud: "game-hud",
  gameOver: "game-over-panel",
} as const;
