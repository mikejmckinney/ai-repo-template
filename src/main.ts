import Phaser from "phaser";
import "./styles.css";
import { createSimulation } from "./shared-simulation/simulation";

const WIDTH = 1280;
const HEIGHT = 720;
const FIXED_STEP_MS = 1000 / 60;
const ASSET_ROOT = "/benchmark-assets/vector-siege/";
const SETTINGS_KEY = "vector-siege-settings";
const HIGH_SCORE_KEY = "vector-siege-high-score";
const DEFAULT_SEED = 23017;

const COLORS = {
  accent: 0x49dcb1,
  accentCss: "#49dcb1",
  background: 0x08111f,
  danger: 0xff4f78,
  highlight: 0xf6c453,
  muted: 0x61728b,
  white: 0xe7f5f0,
};

type Phase = "menu" | "running" | "paused" | "game-over";

interface AudioSettings {
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
}

interface RenderEntity {
  id: number;
  kind?: string;
  x: number;
  y: number;
  health: number;
  maxHealth: number;
  radius?: number;
}

interface RenderPlayer {
  x: number;
  y: number;
  health: number;
  maxHealth: number;
  invulnerableTicks?: number;
  invulnerableUntil?: number;
}

interface RenderState {
  phase: Phase;
  tick: number;
  seed: number;
  score: number;
  wave: number;
  player: RenderPlayer;
  enemies: RenderEntity[];
  projectiles: Array<{ x: number; y: number; previousX?: number; previousY?: number }>;
  completedGame?: { seed: number; finalTick: number } | null;
}

interface SimulationLike {
  state: RenderState;
  start?: () => void;
  pause?: () => void;
  resume?: () => void;
  restart?: (seed?: number) => void;
  step?: (input: {
    moveX: number;
    moveY: number;
    aimX: number;
    aimY: number;
    fire: boolean;
    pause?: boolean;
  }) => void;
  update?: (input: unknown) => void;
}

interface RawSimulationState {
  phase?: string;
  tick?: number;
  seed?: number;
  score?: number;
  wave?: number;
  player?: {
    x?: number;
    y?: number;
    position?: { x: number; y: number };
    health?: number;
    maxHealth?: number;
    invulnerableTicks?: number;
    invulnerabilityTicksRemaining?: number;
    invulnerableUntil?: number;
    invulnerableUntilTick?: number;
  };
  enemies?: Array<{
    id: number;
    kind?: string;
    type?: string;
    x?: number;
    y?: number;
    position?: { x: number; y: number };
    health?: number;
    maxHealth?: number;
    radius?: number;
  }>;
  projectiles?: Array<{
    x?: number;
    y?: number;
    position?: { x: number; y: number };
    previousPosition?: { x: number; y: number };
  }>;
  completedGame?: { seed: number; finalTick: number } | null;
}

const makeSimulation = createSimulation as unknown as (options: {
  seed: number;
  arena: { width: number; height: number };
}) => SimulationLike;

function readAudioSettings(): AudioSettings {
  const fallback: AudioSettings = { musicVolume: 0.55, effectsVolume: 0.55, muted: false };
  try {
    const stored = window.localStorage.getItem(SETTINGS_KEY);
    if (!stored) {
      const musicStored = window.localStorage.getItem("vector-siege-music-volume");
      const effectsStored = window.localStorage.getItem("vector-siege-effects-volume");
      const musicVolume = musicStored === null ? Number.NaN : Number(musicStored);
      const effectsVolume = effectsStored === null ? Number.NaN : Number(effectsStored);
      const muted = window.localStorage.getItem("vector-siege-muted") === "true";
      return {
        musicVolume: Number.isFinite(musicVolume) ? Phaser.Math.Clamp(musicVolume, 0, 1) : fallback.musicVolume,
        effectsVolume: Number.isFinite(effectsVolume) ? Phaser.Math.Clamp(effectsVolume, 0, 1) : fallback.effectsVolume,
        muted,
      };
    }
    const parsed = JSON.parse(stored) as Partial<AudioSettings> & { volume?: number };
    const legacyVolume = typeof parsed.volume === "number" ? Phaser.Math.Clamp(parsed.volume, 0, 1) : fallback.musicVolume;
    return {
      musicVolume: typeof parsed.musicVolume === "number" ? Phaser.Math.Clamp(parsed.musicVolume, 0, 1) : legacyVolume,
      effectsVolume: typeof parsed.effectsVolume === "number" ? Phaser.Math.Clamp(parsed.effectsVolume, 0, 1) : legacyVolume,
      muted: parsed.muted === true,
    };
  } catch {
    return fallback;
  }
}

function writeAudioSettings(settings: AudioSettings): void {
  try {
    window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    window.localStorage.setItem("vector-siege-music-volume", String(settings.musicVolume));
    window.localStorage.setItem("vector-siege-effects-volume", String(settings.effectsVolume));
    window.localStorage.setItem("vector-siege-muted", String(settings.muted));
  } catch {
    // Private browsing and strict evaluator contexts may disable storage.
  }
}

function readHighScore(): number {
  try {
    return Math.max(0, Number(window.localStorage.getItem(HIGH_SCORE_KEY) ?? 0) || 0);
  } catch {
    return 0;
  }
}

function writeHighScore(score: number): void {
  try {
    window.localStorage.setItem(HIGH_SCORE_KEY, String(score));
  } catch {
    // Private browsing and strict evaluator contexts may disable storage.
  }
}

function requestedSeed(): number {
  const value = Number(new URLSearchParams(window.location.search).get("seed"));
  return Number.isFinite(value) ? Math.trunc(value) : DEFAULT_SEED;
}

class VectorSiegeScene extends Phaser.Scene {
  private simulation!: SimulationLike;
  private seed = requestedSeed();
  private accumulator = 0;
  private lastPhase: Phase = "menu";
  private highScore = readHighScore();
  private audioSettings = readAudioSettings();
  private audioUnlocked = false;
  private menuMusic?: Phaser.Sound.BaseSound;
  private gameplayMusic?: Phaser.Sound.BaseSound;
  private lastScore = 0;
  private lastWave = 1;
  private lastHealth = 100;
  private enemyHealth = new Map<number, number>();
  private enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private enemyLabels = new Map<number, Phaser.GameObjects.Text>();
  private playerSprite!: Phaser.GameObjects.Image;
  private background!: Phaser.GameObjects.Image;
  private logo!: Phaser.GameObjects.Image;
  private arenaShade!: Phaser.GameObjects.Rectangle;
  private worldGraphics!: Phaser.GameObjects.Graphics;
  private hudPanel!: Phaser.GameObjects.Rectangle;
  private hudText!: Phaser.GameObjects.Text;
  private hudSubtext!: Phaser.GameObjects.Text;
  private menuKicker!: Phaser.GameObjects.Text;
  private menuTitle!: Phaser.GameObjects.Text;
  private menuCopy!: Phaser.GameObjects.Text;
  private menuRule!: Phaser.GameObjects.Line;
  private menuPanel!: Phaser.GameObjects.Rectangle;
  private menuIcons!: Phaser.GameObjects.Image[];
  private pausePanel!: Phaser.GameObjects.Rectangle;
  private pauseText!: Phaser.GameObjects.Text;
  private pauseSubtext!: Phaser.GameObjects.Text;
  private gameOverPanel!: Phaser.GameObjects.Rectangle;
  private gameOverKicker!: Phaser.GameObjects.Text;
  private gameOverText!: Phaser.GameObjects.Text;
  private gameOverSubtext!: Phaser.GameObjects.Text;
  private statusElement!: HTMLElement;
  private menuActions!: HTMLElement;
  private runActions!: HTMLElement;
  private pauseActions!: HTMLElement;
  private gameOverActions!: HTMLElement;
  private shellElement!: HTMLElement;
  private muteButtons!: HTMLButtonElement[];
  private volumeSlider!: HTMLInputElement;
  private effectsSlider!: HTMLInputElement;
  private pauseKey!: Phaser.Input.Keyboard.Key;
  private spaceKey!: Phaser.Input.Keyboard.Key;
  private keys!: {
    up: Phaser.Input.Keyboard.Key;
    down: Phaser.Input.Keyboard.Key;
    left: Phaser.Input.Keyboard.Key;
    right: Phaser.Input.Keyboard.Key;
    w: Phaser.Input.Keyboard.Key;
    a: Phaser.Input.Keyboard.Key;
    s: Phaser.Input.Keyboard.Key;
    d: Phaser.Input.Keyboard.Key;
  };

  constructor() {
    super("VectorSiege");
  }

  preload(): void {
    this.load.image("menu-background", `${ASSET_ROOT}visuals/menu-background.webp`);
    this.load.image("arena-background", `${ASSET_ROOT}visuals/arena-background.webp`);
    this.load.image("logo", `${ASSET_ROOT}visuals/logo.webp`);
    this.load.image("player", `${ASSET_ROOT}visuals/player.webp`);
    this.load.image("chaser", `${ASSET_ROOT}visuals/enemies/chaser.webp`);
    this.load.image("striker", `${ASSET_ROOT}visuals/enemies/striker.webp`);
    this.load.image("tank", `${ASSET_ROOT}visuals/enemies/tank.webp`);
    this.load.image("heart", `${ASSET_ROOT}visuals/ui/heart.webp`);
    this.load.image("score", `${ASSET_ROOT}visuals/ui/score.webp`);
    this.load.image("wave", `${ASSET_ROOT}visuals/ui/wave.webp`);
    this.load.image("health-pickup", `${ASSET_ROOT}visuals/pickups/health.webp`);
    this.load.image("rapid-fire-pickup", `${ASSET_ROOT}visuals/pickups/rapid-fire.webp`);
    this.load.atlas(
      "impact",
      `${ASSET_ROOT}visuals/effects/impact-atlas.webp`,
      `${ASSET_ROOT}visuals/effects/impact-atlas.json`,
    );
    this.load.atlas(
      "explosion",
      `${ASSET_ROOT}visuals/effects/explosion-atlas.webp`,
      `${ASSET_ROOT}visuals/effects/explosion-atlas.json`,
    );

    this.load.audio("menu-theme", `${ASSET_ROOT}audio/menu-theme.mp3`);
    this.load.audio("gameplay-loop", `${ASSET_ROOT}audio/gameplay-loop.mp3`);
    this.load.audio("shoot", `${ASSET_ROOT}audio/shoot.wav`);
    this.load.audio("enemy-hit", `${ASSET_ROOT}audio/enemy-hit.wav`);
    this.load.audio("player-hit", `${ASSET_ROOT}audio/player-hit.wav`);
    this.load.audio("enemy-defeat", `${ASSET_ROOT}audio/enemy-defeat.wav`);
    this.load.audio("wave-start", `${ASSET_ROOT}audio/wave-start.wav`);
    this.load.audio("game-over", `${ASSET_ROOT}audio/game-over.wav`);
  }

  create(): void {
    this.cameras.main.setBackgroundColor(COLORS.background);
    this.createAnimations();
    this.createPresentation();
    this.createInput();
    this.createDomControls();
    this.makeSimulation();
    this.applyAudioSettings();
    this.showMenu();
  }

  update(_time: number, delta: number): void {
    if (!this.simulation) return;

    this.accumulator += Math.min(delta, 250);
    while (this.accumulator >= FIXED_STEP_MS) {
      if (this.readPhase() === "running") {
        this.stepSimulation();
      }
      this.accumulator -= FIXED_STEP_MS;
    }

    this.renderState();
  }

  private createAnimations(): void {
    const frames = (key: string) =>
      [0, 1, 2, 3].map((index) => ({ key, frame: `frame-${index}` }));
    this.anims.create({ key: "impact-burst", frames: frames("impact"), frameRate: 22, repeat: 0 });
    this.anims.create({ key: "explosion-burst", frames: frames("explosion"), frameRate: 14, repeat: 0 });
  }

  private createPresentation(): void {
    this.background = this.add.image(WIDTH / 2, HEIGHT / 2, "menu-background").setDisplaySize(WIDTH, HEIGHT);
    this.background.setDepth(-10);
    this.arenaShade = this.add.rectangle(WIDTH / 2, HEIGHT / 2, WIDTH, HEIGHT, COLORS.background, 0.18).setDepth(-9);
    this.logo = this.add.image(WIDTH / 2, 132, "logo").setDisplaySize(460, 230).setDepth(1);

    this.menuKicker = this.add
      .text(640, 236, "SINGLE-PLAYER // ARENA PROTOCOL 01", {
        color: COLORS.accentCss,
        fontFamily: "monospace",
        fontSize: "13px",
        fontStyle: "bold",
        letterSpacing: 3,
      })
      .setOrigin(0.5)
      .setDepth(1);
    this.menuTitle = this.add
      .text(640, 276, "HOLD THE VECTOR LINE", {
        color: "#e7f5f0",
        fontFamily: "monospace",
        fontSize: "25px",
        fontStyle: "bold",
        letterSpacing: 3,
      })
      .setOrigin(0.5)
      .setDepth(1);
    this.menuRule = this.add.line(640, 316, 0, 0, 640, 0, COLORS.accent, 0.45).setLineWidth(1).setDepth(1);
    this.menuPanel = this.add
      .rectangle(640, 421, 620, 152, COLORS.background, 0.78)
      .setStrokeStyle(1, COLORS.accent, 0.28)
      .setDepth(0);
    this.menuCopy = this.add
      .text(640, 370, "Outlast the signal storm. Every contact costs a heart.\nEvery clean shot buys another wave.", {
        color: "#b8c9c8",
        fontFamily: "monospace",
        fontSize: "13px",
        align: "center",
        lineSpacing: 6,
      })
      .setOrigin(0.5)
      .setDepth(1);

    this.menuIcons = [
      this.add.image(500, 421, "health-pickup").setDisplaySize(42, 42),
      this.add.image(640, 421, "rapid-fire-pickup").setDisplaySize(42, 42),
      this.add.image(780, 421, "wave").setDisplaySize(36, 36),
    ];
    this.menuIcons.forEach((icon) => icon.setDepth(1));
    this.add
      .text(500, 460, "SURVIVE", { color: "#ff4f78", fontFamily: "monospace", fontSize: "10px", fontStyle: "bold" })
      .setOrigin(0.5)
      .setDepth(1);
    this.add
      .text(640, 460, "BURST FIRE", { color: "#f6c453", fontFamily: "monospace", fontSize: "10px", fontStyle: "bold" })
      .setOrigin(0.5)
      .setDepth(1);
    this.add
      .text(780, 460, "ESCALATE", { color: "#49dcb1", fontFamily: "monospace", fontSize: "10px", fontStyle: "bold" })
      .setOrigin(0.5)
      .setDepth(1);

    this.worldGraphics = this.add.graphics().setDepth(2);
    this.playerSprite = this.add.image(WIDTH / 2, HEIGHT / 2, "player").setDisplaySize(76, 76).setDepth(5);

    this.hudPanel = this.add
      .rectangle(640, 49, 1120, 58, COLORS.background, 0.84)
      .setStrokeStyle(1, COLORS.accent, 0.26)
      .setDepth(7);
    this.hudText = this.add
      .text(90, 31, "SCORE  000000", {
        color: "#e7f5f0",
        fontFamily: "monospace",
        fontSize: "18px",
        fontStyle: "bold",
        letterSpacing: 2,
      })
      .setDepth(8);
    this.hudSubtext = this.add
      .text(90, 57, "WAVE 01   //   VITALS 100 / 100", {
        color: "#61728b",
        fontFamily: "monospace",
        fontSize: "11px",
        letterSpacing: 1,
      })
      .setDepth(8);
    this.add.image(60, 48, "score").setDisplaySize(30, 30).setDepth(8);
    this.add.image(1016, 48, "wave").setDisplaySize(30, 30).setDepth(8);
    this.add
      .text(1040, 39, "SEED", { color: "#61728b", fontFamily: "monospace", fontSize: "9px", letterSpacing: 2 })
      .setDepth(8);
    this.add
      .text(1040, 55, String(this.seed).padStart(6, "0"), {
        color: "#49dcb1",
        fontFamily: "monospace",
        fontSize: "13px",
        fontStyle: "bold",
        letterSpacing: 1,
      })
      .setDepth(8);

    this.pausePanel = this.add
      .rectangle(640, 360, 520, 200, COLORS.background, 0.92)
      .setStrokeStyle(1, COLORS.accent, 0.42)
      .setDepth(20);
    this.pauseText = this.add
      .text(640, 321, "SIGNAL PAUSED", {
        color: COLORS.accentCss,
        fontFamily: "monospace",
        fontSize: "24px",
        fontStyle: "bold",
        letterSpacing: 4,
      })
      .setOrigin(0.5)
      .setDepth(21);
    this.pauseSubtext = this.add
      .text(640, 376, "Simulation held // audio suspended\nResume when your vector is clear.", {
        color: "#a7bfba",
        fontFamily: "monospace",
        fontSize: "12px",
        align: "center",
        lineSpacing: 7,
      })
      .setOrigin(0.5)
      .setDepth(21);

    this.gameOverPanel = this.add
      .rectangle(640, 360, 610, 254, COLORS.background, 0.93)
      .setStrokeStyle(1, COLORS.danger, 0.52)
      .setDepth(20);
    this.gameOverKicker = this.add
      .text(640, 276, "SIGNAL LOST // RUN TERMINATED", {
        color: "#ff4f78",
        fontFamily: "monospace",
        fontSize: "12px",
        fontStyle: "bold",
        letterSpacing: 3,
      })
      .setOrigin(0.5)
      .setDepth(21);
    this.gameOverText = this.add
      .text(640, 324, "GAME OVER", {
        color: "#e7f5f0",
        fontFamily: "monospace",
        fontSize: "34px",
        fontStyle: "bold",
        letterSpacing: 6,
      })
      .setOrigin(0.5)
      .setDepth(21);
    this.gameOverSubtext = this.add
      .text(640, 394, "", {
        color: "#a7bfba",
        fontFamily: "monospace",
        fontSize: "13px",
        align: "center",
        lineSpacing: 8,
      })
      .setOrigin(0.5)
      .setDepth(21);

    this.setMenuObjectsVisible(true);
    this.setRunObjectsVisible(false);
    this.pausePanel.setVisible(false);
    this.pauseText.setVisible(false);
    this.pauseSubtext.setVisible(false);
    this.gameOverPanel.setVisible(false);
    this.gameOverKicker.setVisible(false);
    this.gameOverText.setVisible(false);
    this.gameOverSubtext.setVisible(false);
  }

  private createInput(): void {
    const keyboard = this.input.keyboard;
    if (!keyboard) return;
    this.keys = {
      up: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.UP),
      down: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.DOWN),
      left: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.LEFT),
      right: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.RIGHT),
      w: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W),
      a: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A),
      s: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S),
      d: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D),
    };
    this.pauseKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.P);
    this.spaceKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);
    keyboard.on("keydown", () => this.unlockAudio());
    keyboard.on("keydown-ENTER", () => {
      if (this.readPhase() === "menu" || this.readPhase() === "game-over") this.startRun();
    });
    keyboard.on("keydown-SPACE", () => {
      if (this.readPhase() === "menu") this.startRun();
    });
    keyboard.on("keydown-ESC", () => {
      if (this.readPhase() === "running" || this.readPhase() === "paused") this.togglePause();
    });
    keyboard.on("keydown-P", () => {
      if (this.readPhase() === "running" || this.readPhase() === "paused") this.togglePause();
    });
    this.input.on("pointerdown", () => {
      this.unlockAudio();
      if (this.readPhase() === "menu") this.startRun();
    });
  }

  private createDomControls(): void {
    this.shellElement = document.getElementById("game-shell") as HTMLElement;
    this.statusElement = document.getElementById("screen-reader-status") as HTMLElement;
    this.menuActions = document.getElementById("menu-actions") as HTMLElement;
    this.runActions = document.getElementById("run-actions") as HTMLElement;
    this.pauseActions = document.getElementById("pause-actions") as HTMLElement;
    this.gameOverActions = document.getElementById("game-over-actions") as HTMLElement;
    this.volumeSlider = document.getElementById("volume-slider") as HTMLInputElement;
    this.effectsSlider = document.getElementById("effects-slider") as HTMLInputElement;
    this.muteButtons = Array.from(document.querySelectorAll<HTMLButtonElement>('[data-action="mute"]'));
    this.volumeSlider.value = String(this.audioSettings.musicVolume);
    this.effectsSlider.value = String(this.audioSettings.effectsVolume);

    document.querySelectorAll<HTMLButtonElement>("[data-action]").forEach((button) => {
      button.addEventListener("click", () => {
        this.unlockAudio();
        switch (button.dataset.action) {
          case "start":
            this.startRun();
            break;
          case "pause":
            if (this.readPhase() === "running") this.togglePause();
            break;
          case "resume":
            if (this.readPhase() === "paused") this.togglePause();
            break;
          case "restart":
            this.startRun();
            break;
          case "menu":
            this.returnToMenu();
            break;
          case "mute":
            this.toggleMute();
            break;
        }
      });
    });
    this.volumeSlider.addEventListener("input", () => {
      this.audioSettings.musicVolume = Number(this.volumeSlider.value);
      writeAudioSettings(this.audioSettings);
      this.applyAudioSettings();
    });
    this.effectsSlider.addEventListener("input", () => {
      this.audioSettings.effectsVolume = Number(this.effectsSlider.value);
      writeAudioSettings(this.audioSettings);
      this.applyAudioSettings();
    });
  }

  private makeSimulation(): void {
    this.simulation = makeSimulation({ seed: this.seed, arena: { width: WIDTH, height: HEIGHT } });
    this.lastPhase = this.readPhase();
    this.lastScore = this.readState().score;
    this.lastWave = this.readState().wave;
    this.lastHealth = this.readState().player.health;
  }

  private startRun(): void {
    this.unlockAudio();
    if (this.readPhase() === "menu" && this.simulation.start) {
      this.simulation.start();
    } else if (this.simulation.restart) {
      this.simulation.restart(this.seed);
      if (this.readPhase() !== "running" && this.simulation.start) this.simulation.start();
    } else {
      this.makeSimulation();
      this.simulation.start?.();
    }
    this.accumulator = 0;
    this.lastScore = 0;
    this.lastWave = 1;
    this.lastHealth = this.readState().player.maxHealth;
    this.enemyHealth.clear();
    this.playGameplayMusic();
    this.showRunning();
    this.updateStatus("Run active. Move with WASD or arrows; aim with the pointer and fire with Space.");
  }

  private returnToMenu(): void {
    this.makeSimulation();
    this.enemySprites.forEach((sprite) => sprite.destroy());
    this.enemySprites.clear();
    this.enemyHealth.clear();
    this.stopGameplayMusic();
    this.playMenuMusic();
    this.showMenu();
    this.updateStatus("Vector Siege is ready. Start a new run when you are set.");
  }

  private togglePause(): void {
    const phase = this.readPhase();
    if (phase === "running") {
      this.simulation.pause?.();
      this.sound.pauseAll();
      this.showPaused();
      this.updateStatus("Run paused. Resume to continue the simulation.");
    } else if (phase === "paused") {
      this.simulation.resume?.();
      this.sound.resumeAll();
      this.showRunning();
      this.updateStatus("Run resumed.");
    }
  }

  private toggleMute(): void {
    this.audioSettings.muted = !this.audioSettings.muted;
    writeAudioSettings(this.audioSettings);
    this.applyAudioSettings();
    this.updateStatus(this.audioSettings.muted ? "Audio muted." : "Audio restored.");
  }

  private unlockAudio(): void {
    if (this.audioUnlocked) return;
    this.audioUnlocked = true;
    this.sound.unlock();
    if (this.readPhase() === "menu") this.playMenuMusic();
  }

  private applyAudioSettings(): void {
    this.sound.mute = this.audioSettings.muted;
    this.sound.volume = 1;
    if (this.menuMusic) (this.menuMusic as unknown as { volume: number }).volume = 0.16 * this.audioSettings.musicVolume;
    if (this.gameplayMusic) (this.gameplayMusic as unknown as { volume: number }).volume = 0.16 * this.audioSettings.musicVolume;
    if (this.volumeSlider) this.volumeSlider.value = String(this.audioSettings.musicVolume);
    if (this.effectsSlider) this.effectsSlider.value = String(this.audioSettings.effectsVolume);
    this.muteButtons?.forEach((button) => {
      button.textContent = this.audioSettings.muted ? "AUDIO: OFF" : "AUDIO: ON";
      button.setAttribute("aria-pressed", String(this.audioSettings.muted));
    });
  }

  private playMenuMusic(): void {
    if (!this.audioUnlocked || this.readPhase() === "running" || this.readPhase() === "paused") return;
    this.stopGameplayMusic();
    if (!this.menuMusic) this.menuMusic = this.sound.add("menu-theme", { loop: true, volume: 0.16 });
    if (!this.menuMusic.isPlaying) this.menuMusic.play();
    this.applyAudioSettings();
  }

  private playGameplayMusic(): void {
    this.stopMenuMusic();
    if (!this.gameplayMusic) this.gameplayMusic = this.sound.add("gameplay-loop", { loop: true, volume: 0.16 });
    if (!this.gameplayMusic.isPlaying) this.gameplayMusic.play();
    this.applyAudioSettings();
  }

  private stopMenuMusic(): void {
    if (this.menuMusic?.isPlaying) this.menuMusic.stop();
  }

  private stopGameplayMusic(): void {
    if (this.gameplayMusic?.isPlaying) this.gameplayMusic.stop();
  }

  private playSfx(key: string, volume = 1): void {
    if (!this.audioUnlocked || this.audioSettings.muted) return;
    this.sound.play(key, { volume: volume * this.audioSettings.effectsVolume });
  }

  private stepSimulation(): void {
    const pointer = this.input.activePointer;
    const moveX = (this.keys.right.isDown || this.keys.d.isDown ? 1 : 0) - (this.keys.left.isDown || this.keys.a.isDown ? 1 : 0);
    const moveY = (this.keys.down.isDown || this.keys.s.isDown ? 1 : 0) - (this.keys.up.isDown || this.keys.w.isDown ? 1 : 0);
    const aimX = Number.isFinite(pointer.worldX) ? pointer.worldX : WIDTH / 2;
    const aimY = Number.isFinite(pointer.worldY) ? pointer.worldY : HEIGHT / 2;
    const fire = pointer.primaryDown || this.spaceKey.isDown;
    const input = { moveX, moveY, aimX, aimY, fire };
    if (this.simulation.step) this.simulation.step(input);
    else this.simulation.update?.(input);
    const events = (this.simulation.state as unknown as { events?: Array<{ type?: string }> }).events ?? [];
    if (events.some((event) => event.type === "projectile-fired")) this.playSfx("shoot", 0.28);
  }

  private readPhase(): Phase {
    const phase = this.simulation?.state?.phase;
    if (phase === "running" || phase === "paused" || phase === "game-over" || phase === "menu") return phase;
    return "menu";
  }

  private readState(): RenderState {
    const state = this.simulation.state as unknown as RawSimulationState;
    const rawPlayer = state.player;
    const playerX = rawPlayer?.x ?? rawPlayer?.position?.x ?? WIDTH / 2;
    const playerY = rawPlayer?.y ?? rawPlayer?.position?.y ?? HEIGHT / 2;
    return {
      phase: this.readPhase(),
      tick: Number(state.tick ?? 0),
      seed: Number(state.seed ?? this.seed),
      score: Number(state.score ?? 0),
      wave: Number(state.wave ?? 1),
      player: {
        x: Number(playerX),
        y: Number(playerY),
        health: Number(rawPlayer?.health ?? 100),
        maxHealth: Number(rawPlayer?.maxHealth ?? 100),
        invulnerableTicks: Number(rawPlayer?.invulnerableTicks ?? rawPlayer?.invulnerabilityTicksRemaining ?? 0),
        invulnerableUntil: Number(rawPlayer?.invulnerableUntil ?? rawPlayer?.invulnerableUntilTick ?? 0),
      },
      enemies: Array.isArray(state.enemies)
        ? state.enemies.map((enemy) => ({
            id: Number(enemy.id),
            kind: enemy.kind ?? enemy.type ?? "chaser",
            x: Number(enemy.x ?? enemy.position?.x ?? WIDTH / 2),
            y: Number(enemy.y ?? enemy.position?.y ?? HEIGHT / 2),
            health: Number(enemy.health ?? 1),
            maxHealth: Number(enemy.maxHealth ?? enemy.health ?? 1),
            radius: Number(enemy.radius ?? 16),
          }))
        : [],
      projectiles: Array.isArray(state.projectiles)
        ? state.projectiles.map((projectile) => ({
            x: Number(projectile.x ?? projectile.position?.x ?? 0),
            y: Number(projectile.y ?? projectile.position?.y ?? 0),
            previousX: projectile.previousPosition?.x,
            previousY: projectile.previousPosition?.y,
          }))
        : [],
      completedGame: state.completedGame ?? null,
    };
  }

  private renderState(): void {
    const state = this.readState();
    this.shellElement.dataset.phase = state.phase;
    this.shellElement.dataset.score = String(state.score);
    this.shellElement.dataset.wave = String(state.wave);
    this.shellElement.dataset.tick = String(state.tick);
    this.handlePhaseTransition(state);
    if (state.phase === "menu") return;

    this.hudText.setText(`SCORE  ${String(state.score).padStart(6, "0")}`);
    const hp = Math.max(0, Math.ceil(state.player.health));
    this.hudSubtext.setText(`WAVE ${String(state.wave).padStart(2, "0")}   //   VITALS ${hp} / ${state.player.maxHealth}`);
    if (state.phase === "running") {
      this.updateStatus(`Run active. Score ${state.score}. Wave ${state.wave}.`);
    }
    this.renderWorld(state);

    if (state.score > this.lastScore) {
      this.playSfx("enemy-defeat", 0.42);
      this.lastScore = state.score;
    }
    if (state.wave > this.lastWave) {
      this.playSfx("wave-start", 0.4);
      this.lastWave = state.wave;
    }
    if (state.player.health < this.lastHealth) {
      this.playSfx("player-hit", 0.45);
      this.cameras.main.flash(120, 255, 79, 120);
      this.lastHealth = state.player.health;
    }
  }

  private renderWorld(state: RenderState): void {
    const aim = this.input.activePointer;
    this.playerSprite.setPosition(state.player.x, state.player.y);
    this.playerSprite.setRotation(Math.atan2((aim.worldY || state.player.y) - state.player.y, (aim.worldX || state.player.x) - state.player.x) + Math.PI / 2);
    const invulnerable = (state.player.invulnerableTicks ?? 0) > 0 || (state.player.invulnerableUntil ?? 0) > state.tick;
    this.playerSprite.setAlpha(invulnerable ? 0.48 + Math.sin(state.tick * 0.45) * 0.2 : 1);
    this.playerSprite.setTint(invulnerable ? COLORS.danger : 0xffffff);

    this.worldGraphics.clear();
    this.worldGraphics.lineStyle(2, COLORS.accent, 0.22);
    this.worldGraphics.lineBetween(state.player.x, state.player.y, aim.worldX || state.player.x, aim.worldY || state.player.y);
    for (const projectile of state.projectiles) {
      this.worldGraphics.lineStyle(4, COLORS.highlight, 0.95);
      this.worldGraphics.lineBetween(projectile.previousX ?? projectile.x, projectile.previousY ?? projectile.y, projectile.x, projectile.y);
      this.worldGraphics.fillStyle(COLORS.white, 1);
      this.worldGraphics.fillCircle(projectile.x, projectile.y, 3);
    }

    const activeIds = new Set<number>();
    for (const enemy of state.enemies) {
      activeIds.add(enemy.id);
      const kind = enemy.kind === "tank" ? "tank" : enemy.kind === "striker" ? "striker" : "chaser";
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite || sprite.texture.key !== kind) {
        sprite?.destroy();
        sprite = this.add.image(enemy.x, enemy.y, kind).setDisplaySize(kind === "tank" ? 70 : 58, kind === "tank" ? 70 : 58).setDepth(4);
        this.enemySprites.set(enemy.id, sprite);
      }
      sprite.setPosition(enemy.x, enemy.y);
      sprite.setAlpha(kind === "tank" ? 0.98 : 0.9);
      if (kind === "striker") sprite.setRotation(Math.atan2(state.player.y - enemy.y, state.player.x - enemy.x));

      this.worldGraphics.fillStyle(COLORS.background, 0.76);
      this.worldGraphics.fillRect(enemy.x - 25, enemy.y - 38, 50, 5);
      const healthRatio = Phaser.Math.Clamp(enemy.health / Math.max(1, enemy.maxHealth), 0, 1);
      this.worldGraphics.fillStyle(kind === "tank" ? COLORS.highlight : COLORS.danger, 0.95);
      this.worldGraphics.fillRect(enemy.x - 25, enemy.y - 38, 50 * healthRatio, 5);

      const previousHealth = this.enemyHealth.get(enemy.id);
      if (previousHealth !== undefined && enemy.health < previousHealth) {
        this.spawnEffect(enemy.x, enemy.y, "impact-burst", 0.65);
        this.playSfx("enemy-hit", 0.32);
      }
      this.enemyHealth.set(enemy.id, enemy.health);
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!activeIds.has(id)) {
        const x = sprite.x;
        const y = sprite.y;
        this.spawnEffect(x, y, "explosion-burst", 0.95);
        sprite.destroy();
        this.enemySprites.delete(id);
        this.enemyHealth.delete(id);
      }
    }
  }

  private spawnEffect(x: number, y: number, animation: string, scale: number): void {
    const sprite = this.add.sprite(x, y, animation === "impact-burst" ? "impact" : "explosion", "frame-0").setScale(scale).setDepth(6);
    sprite.play(animation);
    sprite.once("animationcomplete", () => sprite.destroy());
  }

  private handlePhaseTransition(state: RenderState): void {
    if (state.phase === this.lastPhase) return;
    this.lastPhase = state.phase;
    if (state.phase === "game-over") {
      this.stopGameplayMusic();
      this.playSfx("game-over", 0.52);
      if (state.score > this.highScore) {
        this.highScore = state.score;
        writeHighScore(this.highScore);
      }
      const finalTick = state.completedGame?.finalTick ?? state.tick;
      this.gameOverSubtext.setText(
        `SCORE  ${String(state.score).padStart(6, "0")}   //   WAVE ${String(state.wave).padStart(2, "0")}\n` +
          `RUN SEED ${state.seed}   //   FINAL TICK ${finalTick}\n` +
          `HIGH SCORE ${String(this.highScore).padStart(6, "0")}`,
      );
      this.showGameOver();
      this.updateStatus("Game over. Restart without reloading the page to run the vector again.");
    }
  }

  private showMenu(): void {
    this.background.setTexture("menu-background");
    this.arenaShade.setAlpha(0.18);
    this.setMenuObjectsVisible(true);
    this.setRunObjectsVisible(false);
    this.pausePanel.setVisible(false);
    this.pauseText.setVisible(false);
    this.pauseSubtext.setVisible(false);
    this.gameOverPanel.setVisible(false);
    this.gameOverKicker.setVisible(false);
    this.gameOverText.setVisible(false);
    this.gameOverSubtext.setVisible(false);
    this.menuActions.hidden = false;
    this.runActions.hidden = true;
    this.pauseActions.hidden = true;
    this.gameOverActions.hidden = true;
    this.playMenuMusic();
  }

  private showRunning(): void {
    this.background.setTexture("arena-background");
    this.arenaShade.setAlpha(0.26);
    this.setMenuObjectsVisible(false);
    this.setRunObjectsVisible(true);
    this.pausePanel.setVisible(false);
    this.pauseText.setVisible(false);
    this.pauseSubtext.setVisible(false);
    this.gameOverPanel.setVisible(false);
    this.gameOverKicker.setVisible(false);
    this.gameOverText.setVisible(false);
    this.gameOverSubtext.setVisible(false);
    this.menuActions.hidden = true;
    this.runActions.hidden = false;
    this.pauseActions.hidden = true;
    this.gameOverActions.hidden = true;
  }

  private showPaused(): void {
    this.showRunning();
    this.pausePanel.setVisible(true);
    this.pauseText.setVisible(true);
    this.pauseSubtext.setVisible(true);
    this.runActions.hidden = true;
    this.pauseActions.hidden = false;
  }

  private showGameOver(): void {
    this.background.setTexture("arena-background");
    this.setMenuObjectsVisible(false);
    this.setRunObjectsVisible(false);
    this.pausePanel.setVisible(false);
    this.pauseText.setVisible(false);
    this.pauseSubtext.setVisible(false);
    this.gameOverPanel.setVisible(true);
    this.gameOverKicker.setVisible(true);
    this.gameOverText.setVisible(true);
    this.gameOverSubtext.setVisible(true);
    this.menuActions.hidden = true;
    this.runActions.hidden = true;
    this.pauseActions.hidden = true;
    this.gameOverActions.hidden = false;
  }

  private setMenuObjectsVisible(visible: boolean): void {
    this.logo.setVisible(visible);
    this.menuKicker.setVisible(visible);
    this.menuTitle.setVisible(visible);
    this.menuCopy.setVisible(visible);
    this.menuRule.setVisible(visible);
    this.menuPanel.setVisible(visible);
    this.menuIcons.forEach((icon) => icon.setVisible(visible));
  }

  private setRunObjectsVisible(visible: boolean): void {
    this.hudPanel.setVisible(visible);
    this.hudText.setVisible(visible);
    this.hudSubtext.setVisible(visible);
    this.playerSprite.setVisible(visible);
    this.worldGraphics.setVisible(visible);
    this.enemySprites.forEach((sprite) => sprite.setVisible(visible));
    this.children.list
      .filter((child) => child instanceof Phaser.GameObjects.Image && ["score", "wave"].includes((child as Phaser.GameObjects.Image).texture.key))
      .forEach((child) => (child as Phaser.GameObjects.Image).setVisible(visible));
  }

  private updateStatus(message: string): void {
    if (this.statusElement) this.statusElement.textContent = message;
  }
}

new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  width: WIDTH,
  height: HEIGHT,
  backgroundColor: COLORS.background,
  render: {
    antialias: true,
    roundPixels: true,
  },
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: WIDTH,
    height: HEIGHT,
  },
  fps: {
    target: 60,
    smoothStep: true,
  },
  input: {
    keyboard: true,
    mouse: true,
    touch: true,
    activePointers: 1,
  },
  disableContextMenu: true,
  title: "Vector Siege",
  scene: VectorSiegeScene,
});
