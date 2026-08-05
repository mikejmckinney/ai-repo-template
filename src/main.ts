import Phaser from "phaser";
import "./styles.css";
import { AudioManager, type EffectName } from "./game/audio";
import { ArenaScene } from "./game/scene";
import { type SimulationEvent, type SimulationSnapshot } from "./game/simulation";

const DEFAULT_SEED = 20260805;
const HIGH_SCORE_KEY = "vectorSiege.highScore";

const startScreen = getElement<HTMLElement>("start-screen");
const hud = getElement<HTMLElement>("hud");
const pauseScreen = getElement<HTMLElement>("pause-screen");
const gameoverScreen = getElement<HTMLElement>("gameover-screen");
const settingsPanel = getElement<HTMLElement>("audio-settings");
const combatNotice = getElement<HTMLElement>("combat-notice");
const startButton = getElement<HTMLButtonElement>("start-button");
const pauseButton = getElement<HTMLButtonElement>("pause-button");
const resumeButton = getElement<HTMLButtonElement>("resume-button");
const restartButton = getElement<HTMLButtonElement>("restart-button");
const soundButton = getElement<HTMLButtonElement>("sound-button");
const settingsButton = getElement<HTMLButtonElement>("settings-button");
const settingsClose = getElement<HTMLButtonElement>("settings-close");
const musicVolume = getElement<HTMLInputElement>("music-volume");
const effectsVolume = getElement<HTMLInputElement>("effects-volume");
const musicVolumeOutput = getElement<HTMLOutputElement>("music-volume-output");
const effectsVolumeOutput = getElement<HTMLOutputElement>("effects-volume-output");
const scoreValue = getElement<HTMLElement>("score-value");
const waveValue = getElement<HTMLElement>("wave-value");
const healthHearts = getElement<HTMLElement>("health-hearts");
const runStatus = getElement<HTMLElement>("run-status");
const menuHighScore = getElement<HTMLElement>("menu-high-score");
const finalHighScore = getElement<HTMLElement>("final-high-score");
const finalScore = getElement<HTMLElement>("final-score");
const finalWave = getElement<HTMLElement>("final-wave");
const finalTick = getElement<HTMLElement>("final-tick");
const finalSeed = getElement<HTMLElement>("final-seed");
const pauseTick = getElement<HTMLElement>("pause-tick");

const audio = new AudioManager();
let highScore = readHighScore();
let noticeTimeout: number | undefined;
let lastSnapshot: SimulationSnapshot | null = null;
let renderedHealth = "";

menuHighScore.textContent = formatScore(highScore);
const settings = audio.getSettings();
musicVolume.value = String(settings.musicVolume);
effectsVolume.value = String(settings.effectsVolume);
updateVolumeLabels();
updateSoundButton();

const scene = new ArenaScene({
  onEvent: handleSimulationEvent,
  onReady: () => {
    startButton.focus();
  },
  onSnapshot: renderSnapshot,
});

new Phaser.Game({
  type: Phaser.CANVAS,
  parent: "game",
  width: 1280,
  height: 720,
  backgroundColor: "#08111f",
  scene: [scene],
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: 1280,
    height: 720,
  },
  render: {
    antialias: true,
    roundPixels: true,
  },
});

startButton.addEventListener("click", () => {
  void beginMission();
});
restartButton.addEventListener("click", () => {
  void beginMission();
});
pauseButton.addEventListener("click", () => togglePause());
resumeButton.addEventListener("click", () => togglePause());
soundButton.addEventListener("click", () => {
  audio.toggleMute();
  updateSoundButton();
});
settingsButton.addEventListener("click", () => {
  settingsPanel.hidden = !settingsPanel.hidden;
  settingsButton.setAttribute("aria-expanded", String(!settingsPanel.hidden));
});
settingsClose.addEventListener("click", () => closeSettings());
musicVolume.addEventListener("input", () => {
  audio.setMusicVolume(Number(musicVolume.value));
  updateVolumeLabels();
});
effectsVolume.addEventListener("input", () => {
  audio.setEffectsVolume(Number(effectsVolume.value));
  updateVolumeLabels();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    if (settingsPanel.hidden === false) {
      closeSettings();
    } else {
      togglePause();
    }
  }
  if (event.key === "Enter" && lastSnapshot?.status === "menu") {
    void beginMission();
  }
});

async function beginMission(): Promise<void> {
  if (scene.getSnapshot().status === "running") {
    return;
  }
  await unlockAudio();
  scene.startGame(DEFAULT_SEED);
  startScreen.hidden = true;
  pauseScreen.hidden = true;
  gameoverScreen.hidden = true;
  hud.hidden = false;
  closeSettings();
  await audio.playGameplayMusic();
}

function togglePause(): void {
  const status = scene.getSnapshot().status;
  if (status !== "running" && status !== "paused") {
    return;
  }
  scene.togglePause();
  if (scene.getSnapshot().status === "paused") {
    audio.pauseGameplayMusic();
  } else {
    void audio.resumeGameplayMusic();
  }
}

async function unlockAudio(): Promise<void> {
  try {
    await audio.unlock();
  } catch (error: unknown) {
    console.warn("Vector Siege audio unlock did not complete; continuing with visual feedback.", error);
  }
}

function handleSimulationEvent(event: SimulationEvent): void {
  const effectByEvent: Partial<Record<SimulationEvent["type"], EffectName>> = {
    shot: "shoot",
    enemyHit: "enemyHit",
    enemyDefeated: "enemyDefeat",
    playerHit: "playerHit",
    waveStarted: "waveStart",
  };
  const effect = effectByEvent[event.type];
  if (effect) {
    audio.playEffect(effect);
  }
  if (event.type === "waveStarted") {
    showNotice(`WAVE ${formatWave(event.wave)} // INBOUND`);
  } else if (event.type === "waveCleared") {
    showNotice("WAVE CLEARED // RESETTING");
  } else if (event.type === "enemyDefeated") {
    showNotice(`TARGET DOWN +${event.score}`);
  } else if (event.type === "playerHit") {
    showNotice("CORE HIT // EVADE");
  } else if (event.type === "gameOver") {
    audio.stopAll();
    audio.playEffect("gameOver");
    void audio.playMenuMusic();
  }
}

function renderSnapshot(snapshot: SimulationSnapshot): void {
  if (snapshot.status === "gameover" && snapshot.completedGame && snapshot.completedGame.score > highScore) {
    writeHighScore(snapshot.completedGame.score);
  }
  lastSnapshot = snapshot;
  scoreValue.textContent = formatScore(snapshot.score);
  waveValue.textContent = formatWave(snapshot.wave);
  pauseTick.textContent = formatTick(snapshot.tick);
  const healthKey = `${snapshot.player.health}/${snapshot.player.maxHealth}`;
  if (healthKey !== renderedHealth) {
    renderedHealth = healthKey;
    renderHealth(snapshot.player.health, snapshot.player.maxHealth);
  }

  if (snapshot.status === "menu") {
    startScreen.hidden = false;
    hud.hidden = true;
    pauseScreen.hidden = true;
    gameoverScreen.hidden = true;
    runStatus.textContent = "READY // 01";
    return;
  }
  if (snapshot.status === "running") {
    startScreen.hidden = true;
    hud.hidden = false;
    pauseScreen.hidden = true;
    gameoverScreen.hidden = true;
    runStatus.textContent = `LIVE // ${formatTick(snapshot.tick)}`;
    return;
  }
  if (snapshot.status === "paused") {
    hud.hidden = false;
    pauseScreen.hidden = false;
    gameoverScreen.hidden = true;
    runStatus.textContent = `PAUSED // ${formatTick(snapshot.tick)}`;
    return;
  }

  hud.hidden = false;
  startScreen.hidden = true;
  pauseScreen.hidden = true;
  gameoverScreen.hidden = false;
  runStatus.textContent = "OFFLINE // RUN ENDED";
  finalScore.textContent = formatScore(snapshot.completedGame?.score ?? snapshot.score);
  finalWave.textContent = formatWave(snapshot.completedGame?.wave ?? snapshot.wave);
  finalTick.textContent = formatTick(snapshot.completedGame?.finalTick ?? snapshot.tick);
  finalSeed.textContent = String(snapshot.completedGame?.seed ?? snapshot.seed);
  finalHighScore.textContent = formatScore(highScore);
}

function renderHealth(health: number, maxHealth: number): void {
  healthHearts.innerHTML = "";
  for (let index = 0; index < maxHealth; index += 1) {
    const heart = document.createElement("img");
    heart.src = "/benchmark-assets/vector-siege/visuals/ui/heart.webp";
    heart.alt = index < health ? "core integrity" : "empty core integrity";
    heart.className = index < health ? "" : "empty";
    healthHearts.appendChild(heart);
  }
}

function showNotice(message: string): void {
  combatNotice.textContent = message;
  combatNotice.classList.add("visible");
  if (noticeTimeout !== undefined) {
    window.clearTimeout(noticeTimeout);
  }
  noticeTimeout = window.setTimeout(() => {
    combatNotice.classList.remove("visible");
    noticeTimeout = undefined;
  }, 1100);
}

function updateSoundButton(): void {
  const muted = audio.getSettings().muted;
  soundButton.textContent = muted ? "SOUND OFF" : "SOUND ON";
  soundButton.setAttribute("aria-pressed", String(muted));
  soundButton.setAttribute("aria-label", muted ? "Unmute sound" : "Mute sound");
}

function updateVolumeLabels(): void {
  musicVolumeOutput.textContent = `${Math.round(Number(musicVolume.value) * 100)}%`;
  effectsVolumeOutput.textContent = `${Math.round(Number(effectsVolume.value) * 100)}%`;
}

function closeSettings(): void {
  settingsPanel.hidden = true;
  settingsButton.setAttribute("aria-expanded", "false");
}

function readHighScore(): number {
  try {
    const value = Number(window.localStorage.getItem(HIGH_SCORE_KEY));
    return Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
  } catch (error: unknown) {
    console.warn("Vector Siege could not read the local high score.", error);
    return 0;
  }
}

function writeHighScore(score: number): void {
  highScore = Math.max(highScore, score);
  menuHighScore.textContent = formatScore(highScore);
  finalHighScore.textContent = formatScore(highScore);
  try {
    window.localStorage.setItem(HIGH_SCORE_KEY, String(highScore));
  } catch (error: unknown) {
    console.warn("Vector Siege could not persist the local high score.", error);
  }
}

function formatScore(score: number): string {
  return Math.max(0, Math.floor(score)).toString().padStart(6, "0");
}

function formatWave(wave: number): string {
  return Math.max(0, Math.floor(wave)).toString().padStart(2, "0");
}

function formatTick(tick: number): string {
  return Math.max(0, Math.floor(tick)).toString().padStart(4, "0");
}

function getElement<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);
  if (!element) {
    throw new Error(`Vector Siege UI is missing #${id}.`);
  }
  return element as T;
}
