import Phaser from "phaser";
import {
  ARENA_BOUNDS,
  ArenaSimulation,
  FIXED_DT,
  GAME_HEIGHT,
  GAME_WIDTH,
  type EnemyKind,
  type SimulationEvent,
  type SimulationInput,
} from "./game/simulation";

const ASSET_ROOT = "/benchmark-assets/vector-siege";
const COLORS = {
  accent: 0x49dcb1,
  background: 0x08111f,
  danger: 0xff4f78,
  highlight: 0xf6c453,
  muted: 0x61728b,
  white: 0xf2f7ff,
  panel: 0x101d30,
};

const STORAGE = {
  audio: "vector-siege-audio-preferences",
  highScore: "vector-siege-high-score",
  completions: "vector-siege-completions",
};

interface AudioPreferences {
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
}

interface GameButton {
  background: Phaser.GameObjects.Rectangle;
  label: Phaser.GameObjects.Text;
}

interface EnemyVisual {
  sprite: Phaser.GameObjects.Sprite;
  healthBar: Phaser.GameObjects.Graphics;
}

interface EffectVisual {
  sprite: Phaser.GameObjects.Sprite;
  elapsed: number;
  duration: number;
  atlasKey: "impact" | "explosion";
}

function readAudioPreferences(): AudioPreferences {
  const fallback: AudioPreferences = {
    musicVolume: 0.22,
    effectsVolume: 0.46,
    muted: false,
  };
  try {
    const value = window.localStorage.getItem(STORAGE.audio);
    if (!value) return fallback;
    const parsed = JSON.parse(value) as Partial<AudioPreferences>;
    return {
      musicVolume: Math.max(0, Math.min(1, parsed.musicVolume ?? fallback.musicVolume)),
      effectsVolume: Math.max(0, Math.min(1, parsed.effectsVolume ?? fallback.effectsVolume)),
      muted: parsed.muted ?? fallback.muted,
    };
  } catch {
    return fallback;
  }
}

function writeAudioPreferences(preferences: AudioPreferences): void {
  try {
    window.localStorage.setItem(STORAGE.audio, JSON.stringify(preferences));
  } catch {
    // Storage is an enhancement; the run remains playable when it is unavailable.
  }
}

function readHighScore(): number {
  try {
    return Number(window.localStorage.getItem(STORAGE.highScore) ?? 0) || 0;
  } catch {
    return 0;
  }
}

function writeCompletion(record: { seed: string; finalTick: number; score: number; wave: number }): void {
  try {
    const current = JSON.parse(window.localStorage.getItem(STORAGE.completions) ?? "[]") as unknown;
    const records = Array.isArray(current) ? current : [];
    records.push(record);
    window.localStorage.setItem(STORAGE.completions, JSON.stringify(records));
    const highScore = Math.max(readHighScore(), record.score);
    window.localStorage.setItem(STORAGE.highScore, String(highScore));
  } catch {
    // A private browsing context may reject localStorage writes.
  }
}

function getRunSeed(): string {
  const querySeed = new URLSearchParams(window.location.search).get("seed");
  return querySeed?.trim() || "stage1-demo-2026";
}

class VectorSiegeScene extends Phaser.Scene {
  private simulation: ArenaSimulation | null = null;
  private mode: "menu" | "running" | "paused" | "gameover" = "menu";
  private readonly runSeed = getRunSeed();
  private readonly audioPreferences = readAudioPreferences();
  private accumulator = 0;
  private pointerFiring = false;
  private pointerMoved = false;
  private aimX = GAME_WIDTH / 2 + 240;
  private aimY = GAME_HEIGHT / 2 + 18;
  private currentMusic: Phaser.Sound.BaseSound | null = null;
  private musicRequest = 0;
  private highScore = readHighScore();

  private keyW!: Phaser.Input.Keyboard.Key;
  private keyA!: Phaser.Input.Keyboard.Key;
  private keyS!: Phaser.Input.Keyboard.Key;
  private keyD!: Phaser.Input.Keyboard.Key;
  private keySpace!: Phaser.Input.Keyboard.Key;
  private keyEnter!: Phaser.Input.Keyboard.Key;
  private keyP!: Phaser.Input.Keyboard.Key;
  private keyM!: Phaser.Input.Keyboard.Key;
  private keyEscape!: Phaser.Input.Keyboard.Key;
  private keyR!: Phaser.Input.Keyboard.Key;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private statusNode: HTMLElement | null = null;

  private menuBackground!: Phaser.GameObjects.Image;
  private arenaBackground!: Phaser.GameObjects.Image;
  private logo!: Phaser.GameObjects.Image;
  private menuEyebrow!: Phaser.GameObjects.Text;
  private menuTitle!: Phaser.GameObjects.Text;
  private menuTagline!: Phaser.GameObjects.Text;
  private menuControls!: Phaser.GameObjects.Text;
  private menuHighScore!: Phaser.GameObjects.Text;
  private menuAudioHint!: Phaser.GameObjects.Text;
  private startButton!: GameButton;
  private menuMuteButton!: GameButton;
  private volumeDownButton!: GameButton;
  private volumeUpButton!: GameButton;

  private hudPanel!: Phaser.GameObjects.Rectangle;
  private scoreIcon!: Phaser.GameObjects.Image;
  private waveIcon!: Phaser.GameObjects.Image;
  private scoreText!: Phaser.GameObjects.Text;
  private waveText!: Phaser.GameObjects.Text;
  private healthLabel!: Phaser.GameObjects.Text;
  private seedText!: Phaser.GameObjects.Text;
  private controlsHint!: Phaser.GameObjects.Text;
  private heartIcons: Phaser.GameObjects.Image[] = [];
  private pauseButton!: GameButton;
  private hudMuteButton!: GameButton;

  private reticle!: Phaser.GameObjects.Graphics;
  private playerSprite!: Phaser.GameObjects.Sprite;
  private bulletVisuals = new Map<number, Phaser.GameObjects.Arc>();
  private enemyVisuals = new Map<number, EnemyVisual>();
  private enemyFlashUntil = new Map<number, number>();
  private effects: EffectVisual[] = [];

  private pauseShade!: Phaser.GameObjects.Rectangle;
  private pausePanel!: Phaser.GameObjects.Rectangle;
  private pauseTitle!: Phaser.GameObjects.Text;
  private pauseCopy!: Phaser.GameObjects.Text;
  private pauseResumeButton!: GameButton;
  private pauseMuteButton!: GameButton;
  private pauseMenuButton!: GameButton;

  private gameOverShade!: Phaser.GameObjects.Rectangle;
  private gameOverPanel!: Phaser.GameObjects.Rectangle;
  private gameOverTitle!: Phaser.GameObjects.Text;
  private gameOverSummary!: Phaser.GameObjects.Text;
  private gameOverHint!: Phaser.GameObjects.Text;
  private restartButton!: GameButton;
  private gameOverMenuButton!: GameButton;

  public constructor() {
    super("VectorSiegeScene");
  }

  public preload(): void {
    this.load.image("menu-background", `${ASSET_ROOT}/visuals/menu-background.webp`);
    this.load.image("arena-background", `${ASSET_ROOT}/visuals/arena-background.webp`);
    this.load.image("logo", `${ASSET_ROOT}/visuals/logo.webp`);
    this.load.image("player", `${ASSET_ROOT}/visuals/player.webp`);
    this.load.image("enemy-chaser", `${ASSET_ROOT}/visuals/enemies/chaser.webp`);
    this.load.image("enemy-striker", `${ASSET_ROOT}/visuals/enemies/striker.webp`);
    this.load.image("enemy-tank", `${ASSET_ROOT}/visuals/enemies/tank.webp`);
    this.load.image("pickup-health", `${ASSET_ROOT}/visuals/pickups/health.webp`);
    this.load.image("pickup-rapid-fire", `${ASSET_ROOT}/visuals/pickups/rapid-fire.webp`);
    this.load.image("ui-heart", `${ASSET_ROOT}/visuals/ui/heart.webp`);
    this.load.image("ui-score", `${ASSET_ROOT}/visuals/ui/score.webp`);
    this.load.image("ui-wave", `${ASSET_ROOT}/visuals/ui/wave.webp`);
    this.load.atlas(
      "impact",
      `${ASSET_ROOT}/visuals/effects/impact-atlas.webp`,
      `${ASSET_ROOT}/visuals/effects/impact-atlas.json`,
    );
    this.load.atlas(
      "explosion",
      `${ASSET_ROOT}/visuals/effects/explosion-atlas.webp`,
      `${ASSET_ROOT}/visuals/effects/explosion-atlas.json`,
    );

    this.load.audio("menu-theme", `${ASSET_ROOT}/audio/menu-theme.mp3`);
    this.load.audio("gameplay-loop", `${ASSET_ROOT}/audio/gameplay-loop.mp3`);
    this.load.audio("shoot", `${ASSET_ROOT}/audio/shoot.wav`);
    this.load.audio("enemy-hit", `${ASSET_ROOT}/audio/enemy-hit.wav`);
    this.load.audio("player-hit", `${ASSET_ROOT}/audio/player-hit.wav`);
    this.load.audio("enemy-defeat", `${ASSET_ROOT}/audio/enemy-defeat.wav`);
    this.load.audio("wave-start", `${ASSET_ROOT}/audio/wave-start.wav`);
    this.load.audio("game-over", `${ASSET_ROOT}/audio/game-over.wav`);
  }

  public create(): void {
    this.cameras.main.setBackgroundColor(COLORS.background);
    this.statusNode = document.getElementById("game-status");
    this.game.canvas.setAttribute("aria-label", "Vector Siege arena shooter");
    this.setupInput();
    this.setupBackgrounds();
    this.setupMenu();
    this.setupHud();
    this.setupOverlays();
    this.showMenu();
    this.applyMuteState();
    this.playMusic("menu-theme");
    this.updateStatusNode();
  }

  public update(_time: number, delta: number): void {
    this.updateEffects(delta);
    this.handleHotkeys();

    if (!this.simulation || this.mode !== "running") {
      return;
    }

    this.accumulator += Math.min(delta, 250) / 1000;
    let steps = 0;
    while (this.accumulator >= FIXED_DT && steps < 8) {
      this.accumulator -= FIXED_DT;
      const events = this.simulation.step(this.sampleInput());
      this.handleSimulationEvents(events);
      steps += 1;
    }

    this.syncWorldVisuals();
    this.updateHud();
    this.updateStatusNode();
  }

  private setupInput(): void {
    const keyboard = this.input.keyboard;
    if (!keyboard) throw new Error("Keyboard input is unavailable");
    this.cursors = keyboard.createCursorKeys();
    this.keyW = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W);
    this.keyA = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A);
    this.keyS = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S);
    this.keyD = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D);
    this.keySpace = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);
    this.keyEnter = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ENTER);
    this.keyP = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.P);
    this.keyM = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.M);
    this.keyEscape = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC);
    this.keyR = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.R);
    keyboard.addCapture([
      Phaser.Input.Keyboard.KeyCodes.SPACE,
      Phaser.Input.Keyboard.KeyCodes.UP,
      Phaser.Input.Keyboard.KeyCodes.DOWN,
      Phaser.Input.Keyboard.KeyCodes.LEFT,
      Phaser.Input.Keyboard.KeyCodes.RIGHT,
    ]);

    this.input.on(
      "pointermove",
      (pointer: Phaser.Input.Pointer) => {
        this.pointerMoved = true;
        this.aimX = pointer.x;
        this.aimY = pointer.y;
      },
      this,
    );
    this.input.on(
      "pointerdown",
      (pointer: Phaser.Input.Pointer, currentlyOver: Phaser.GameObjects.GameObject[]) => {
        if (currentlyOver?.length) return;
        this.aimX = pointer.x;
        this.aimY = pointer.y;
        this.pointerMoved = true;
        this.pointerFiring = true;
        if (this.mode === "menu") {
          this.startGame();
        }
      },
      this,
    );
    this.input.on("pointerup", () => {
      this.pointerFiring = false;
    }, this);
    this.input.on("pointerout", () => {
      this.pointerFiring = false;
    }, this);
  }

  private setupBackgrounds(): void {
    this.menuBackground = this.add
      .image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "menu-background")
      .setDisplaySize(GAME_WIDTH, GAME_HEIGHT)
      .setDepth(0);
    this.arenaBackground = this.add
      .image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "arena-background")
      .setDisplaySize(GAME_WIDTH, GAME_HEIGHT)
      .setDepth(0)
      .setVisible(false);

    this.reticle = this.add.graphics().setDepth(18);
    this.playerSprite = this.add
      .sprite(GAME_WIDTH / 2, GAME_HEIGHT / 2, "player")
      .setDisplaySize(66, 66)
      .setDepth(16);
  }

  private setupMenu(): void {
    this.logo = this.add
      .image(GAME_WIDTH / 2, 146, "logo")
      .setDisplaySize(384, 192)
      .setDepth(2);
    this.menuEyebrow = this.add
      .text(GAME_WIDTH / 2, 266, "STAGE 01  /  SOLO ARENA", this.textStyle(13, "#49dcb1"))
      .setOrigin(0.5)
      .setDepth(2);
    this.menuTitle = this.add
      .text(GAME_WIDTH / 2, 310, "HOLD THE LINE", this.textStyle(32, "#f2f7ff", true))
      .setOrigin(0.5)
      .setDepth(2);
    this.menuTagline = this.add
      .text(
        GAME_WIDTH / 2,
        352,
        "A deterministic vector assault is inbound. Survive the wave.",
        this.textStyle(16, "#b5c5d8"),
      )
      .setOrigin(0.5)
      .setDepth(2);
    this.menuControls = this.add
      .text(
        GAME_WIDTH / 2,
        419,
        "WASD / ARROWS  MOVE       POINTER  AIM       SPACE / CLICK  FIRE       P  PAUSE",
        this.textStyle(13, "#d9e7f5"),
      )
      .setOrigin(0.5)
      .setDepth(2);
    this.menuHighScore = this.add
      .text(GAME_WIDTH / 2, 631, "HIGH SCORE  000000", this.textStyle(13, "#f6c453", true))
      .setOrigin(0.5)
      .setDepth(2);
    this.menuAudioHint = this.add
      .text(GAME_WIDTH / 2, 665, "AUDIO IS READY AFTER YOUR FIRST INPUT", this.textStyle(11, "#61728b"))
      .setOrigin(0.5)
      .setDepth(2);

    this.startButton = this.makeButton(515, 520, 250, 58, "START RUN", () => this.startGame(), true);
    this.menuMuteButton = this.makeButton(790, 520, 180, 58, "MUTE AUDIO", () => this.toggleMute(), false);
    this.volumeDownButton = this.makeButton(552, 584, 48, 32, "−", () => this.adjustVolume(-0.05), false);
    this.volumeUpButton = this.makeButton(728, 584, 48, 32, "+", () => this.adjustVolume(0.05), false);
    this.add
      .text(GAME_WIDTH / 2, 600, "MUSIC / SFX VOLUME", this.textStyle(11, "#9bb0c7"))
      .setOrigin(0.5)
      .setDepth(2);
  }

  private setupHud(): void {
    this.hudPanel = this.add
      .rectangle(GAME_WIDTH / 2, 34, GAME_WIDTH, 68, COLORS.background, 0.96)
      .setDepth(40);
    this.scoreIcon = this.add.image(44, 34, "ui-score").setDisplaySize(28, 28).setDepth(41);
    this.scoreText = this.add.text(65, 17, "SCORE\n000000", this.textStyle(15, "#f6c453", true)).setDepth(41);
    this.waveIcon = this.add.image(212, 34, "ui-wave").setDisplaySize(28, 28).setDepth(41);
    this.waveText = this.add.text(233, 17, "WAVE\n01", this.textStyle(15, "#49dcb1", true)).setDepth(41);
    this.healthLabel = this.add.text(362, 22, "HULL", this.textStyle(12, "#9bb0c7", true)).setDepth(41);
    for (let index = 0; index < 3; index += 1) {
      this.heartIcons.push(
        this.add.image(418 + index * 30, 34, "ui-heart").setDisplaySize(22, 22).setDepth(41),
      );
    }
    this.seedText = this.add.text(548, 25, "SEED  stage1-demo-2026", this.textStyle(11, "#61728b")).setDepth(41);
    this.controlsHint = this.add
      .text(1008, 22, "P  PAUSE   M  MUTE", this.textStyle(11, "#9bb0c7"))
      .setOrigin(0, 0)
      .setDepth(41);
    this.pauseButton = this.makeButton(1133, 34, 74, 32, "PAUSE", () => this.togglePause(), false);
    this.hudMuteButton = this.makeButton(1223, 34, 62, 32, "MUTE", () => this.toggleMute(), false);
  }

  private setupOverlays(): void {
    this.pauseShade = this.add.rectangle(GAME_WIDTH / 2, GAME_HEIGHT / 2, GAME_WIDTH, GAME_HEIGHT, 0x030812, 0.75).setDepth(80);
    this.pausePanel = this.add.rectangle(GAME_WIDTH / 2, 315, 480, 280, COLORS.panel, 0.98).setDepth(81);
    this.pauseTitle = this.add.text(GAME_WIDTH / 2, 226, "SYSTEM PAUSED", this.textStyle(30, "#f2f7ff", true)).setOrigin(0.5).setDepth(82);
    this.pauseCopy = this.add
      .text(GAME_WIDTH / 2, 280, "The arena is frozen. Audio follows your pause state.", this.textStyle(14, "#b5c5d8"))
      .setOrigin(0.5)
      .setDepth(82);
    this.pauseResumeButton = this.makeButton(480, 365, 190, 48, "RESUME", () => this.togglePause(), false);
    this.pauseMuteButton = this.makeButton(700, 365, 190, 48, "MUTE AUDIO", () => this.toggleMute(), false);
    this.pauseMenuButton = this.makeButton(590, 440, 190, 42, "QUIT TO MENU", () => this.goToMenu(), false);

    this.gameOverShade = this.add.rectangle(GAME_WIDTH / 2, GAME_HEIGHT / 2, GAME_WIDTH, GAME_HEIGHT, 0x030812, 0.78).setDepth(90);
    this.gameOverPanel = this.add.rectangle(GAME_WIDTH / 2, 333, 540, 405, COLORS.panel, 0.99).setDepth(91);
    this.gameOverTitle = this.add.text(GAME_WIDTH / 2, 196, "SIGNAL LOST", this.textStyle(36, "#ff4f78", true)).setOrigin(0.5).setDepth(92);
    this.gameOverSummary = this.add.text(GAME_WIDTH / 2, 284, "", this.textStyle(18, "#f2f7ff", true, "center")).setOrigin(0.5).setDepth(92);
    this.gameOverHint = this.add
      .text(GAME_WIDTH / 2, 388, "RUN DATA SAVED LOCALLY  /  PRESS ENTER TO RESTART", this.textStyle(11, "#9bb0c7"))
      .setOrigin(0.5)
      .setDepth(92);
    this.restartButton = this.makeButton(505, 470, 230, 52, "RESTART RUN", () => this.startGame(), false);
    this.gameOverMenuButton = this.makeButton(775, 470, 230, 52, "MAIN MENU", () => this.goToMenu(), false);

    this.setPauseVisible(false);
    this.setGameOverVisible(false);
  }

  private makeButton(
    x: number,
    y: number,
    width: number,
    height: number,
    label: string,
    callback: () => void,
    primary: boolean,
  ): GameButton {
    const background = this.add
      .rectangle(x, y, width, height, primary ? COLORS.accent : COLORS.panel, primary ? 0.98 : 0.96)
      .setStrokeStyle(1, primary ? COLORS.accent : COLORS.muted, 0.9)
      .setDepth(55)
      .setInteractive({ useHandCursor: true });
    const text = this.add
      .text(x, y, label, this.textStyle(primary ? 15 : 12, primary ? "#08111f" : "#d9e7f5", true))
      .setOrigin(0.5)
      .setDepth(56);
    background.on(
      "pointerdown",
      (_pointer: Phaser.Input.Pointer, _localX: number, _localY: number, event: Phaser.Types.Input.EventData) => {
        event.stopPropagation();
        callback();
      },
      this,
    );
    background.on("pointerover", () => {
      background.setFillStyle(primary ? 0x72f0ca : 0x1b304a, primary ? 1 : 1);
    });
    background.on("pointerout", () => {
      background.setFillStyle(primary ? COLORS.accent : COLORS.panel, primary ? 0.98 : 0.96);
    });
    return { background, label: text };
  }

  private textStyle(size: number, color: string, bold = false, align = "left"): Phaser.Types.GameObjects.Text.TextStyle {
    return {
      fontFamily: "Arial, Helvetica, sans-serif",
      fontSize: `${size}px`,
      fontStyle: bold ? "bold" : "normal",
      color,
      align,
      stroke: "#08111f",
      strokeThickness: bold ? 2 : 0,
      shadow: { offsetX: 0, offsetY: 2, color: "#000000", blur: 4, fill: true },
    };
  }

  private startGame(): void {
    this.unlockAudio();
    this.clearWorldVisuals();
    this.simulation = new ArenaSimulation(this.runSeed);
    const events = this.simulation.start();
    this.accumulator = 0;
    this.pointerFiring = false;
    this.pointerMoved = false;
    this.aimX = this.simulation.player.x + 240;
    this.aimY = this.simulation.player.y;
    this.mode = "running";
    this.menuBackground.setVisible(false);
    this.logo.setVisible(false);
    this.menuEyebrow.setVisible(false);
    this.menuTitle.setVisible(false);
    this.menuTagline.setVisible(false);
    this.menuControls.setVisible(false);
    this.menuHighScore.setVisible(false);
    this.menuAudioHint.setVisible(false);
    this.setButtonVisible(this.startButton, false);
    this.setButtonVisible(this.menuMuteButton, false);
    this.setButtonVisible(this.volumeDownButton, false);
    this.setButtonVisible(this.volumeUpButton, false);
    this.arenaBackground.setVisible(true);
    this.playerSprite.setVisible(true);
    this.hudPanel.setVisible(true);
    this.setButtonVisible(this.pauseButton, true);
    this.setButtonVisible(this.hudMuteButton, true);
    this.reticle.setVisible(true);
    this.setPauseVisible(false);
    this.setGameOverVisible(false);
    this.playMusic("gameplay-loop");
    this.handleSimulationEvents(events);
    this.syncWorldVisuals();
    this.updateHud();
    this.updateStatusNode();
  }

  private showMenu(): void {
    this.mode = "menu";
    this.simulation = null;
    this.clearWorldVisuals();
    this.menuBackground.setVisible(true);
    this.logo.setVisible(true);
    this.menuEyebrow.setVisible(true);
    this.menuTitle.setVisible(true);
    this.menuTagline.setVisible(true);
    this.menuControls.setVisible(true);
    this.menuHighScore.setVisible(true).setText(`HIGH SCORE  ${this.formatScore(this.highScore)}`);
    this.menuAudioHint.setVisible(true);
    this.setButtonVisible(this.startButton, true);
    this.setButtonVisible(this.menuMuteButton, true);
    this.setButtonVisible(this.volumeDownButton, true);
    this.setButtonVisible(this.volumeUpButton, true);
    this.arenaBackground.setVisible(false);
    this.playerSprite.setVisible(false);
    this.hudPanel.setVisible(false);
    this.setButtonVisible(this.pauseButton, false);
    this.setButtonVisible(this.hudMuteButton, false);
    this.reticle.setVisible(false);
    this.setPauseVisible(false);
    this.setGameOverVisible(false);
    this.playMusic("menu-theme");
    this.updateAudioLabels();
    this.updateStatusNode();
  }

  private goToMenu(): void {
    this.unlockAudio();
    this.stopMusic();
    this.showMenu();
  }

  private handleHotkeys(): void {
    if (Phaser.Input.Keyboard.JustDown(this.keyM)) {
      this.toggleMute();
    }
    if (this.mode === "menu") {
      if (Phaser.Input.Keyboard.JustDown(this.keyEnter) || Phaser.Input.Keyboard.JustDown(this.keySpace)) {
        this.startGame();
      }
      return;
    }
    if (this.mode === "gameover") {
      if (Phaser.Input.Keyboard.JustDown(this.keyEnter) || Phaser.Input.Keyboard.JustDown(this.keySpace)) {
        this.startGame();
      }
      return;
    }
    if (Phaser.Input.Keyboard.JustDown(this.keyR)) {
      this.startGame();
      return;
    }
    if (Phaser.Input.Keyboard.JustDown(this.keyP) || Phaser.Input.Keyboard.JustDown(this.keyEscape)) {
      this.togglePause();
    }
  }

  private togglePause(): void {
    if (!this.simulation) return;
    if (this.mode === "running") {
      this.mode = "paused";
      this.simulation.pause();
      this.setPauseVisible(true);
      this.pointerFiring = false;
      this.sound.pauseAll();
      this.updateStatusNode();
    } else if (this.mode === "paused") {
      this.mode = "running";
      this.simulation.resume();
      this.setPauseVisible(false);
      this.sound.resumeAll();
      this.updateStatusNode();
    }
  }

  private toggleMute(): void {
    this.audioPreferences.muted = !this.audioPreferences.muted;
    writeAudioPreferences(this.audioPreferences);
    this.applyMuteState();
    this.updateAudioLabels();
    this.updateStatusNode();
  }

  private adjustVolume(delta: number): void {
    this.audioPreferences.musicVolume = Math.max(0, Math.min(1, this.audioPreferences.musicVolume + delta));
    this.audioPreferences.effectsVolume = Math.max(0, Math.min(1, this.audioPreferences.effectsVolume + delta));
    writeAudioPreferences(this.audioPreferences);
    this.updateAudioLabels();
  }

  private updateAudioLabels(): void {
    const muteLabel = this.audioPreferences.muted ? "UNMUTE" : "MUTE AUDIO";
    this.menuMuteButton.label.setText(muteLabel);
    this.pauseMuteButton.label.setText(muteLabel);
    this.hudMuteButton.label.setText(this.audioPreferences.muted ? "ON" : "MUTE");
    this.menuAudioHint.setText(
      `${this.audioPreferences.muted ? "AUDIO MUTED" : "AUDIO LIVE"}  /  VOLUME ${Math.round(this.audioPreferences.musicVolume * 100)}%`,
    );
  }

  private applyMuteState(): void {
    this.sound.setMute(this.audioPreferences.muted);
    this.sound.setVolume(1);
  }

  private unlockAudio(): void {
    if (this.sound.locked) {
      this.sound.unlock();
    }
  }

  private playMusic(key: "menu-theme" | "gameplay-loop"): void {
    if (this.currentMusic?.key === key && (this.currentMusic.isPlaying || this.currentMusic.isPaused)) {
      return;
    }
    this.stopMusic();
    const request = ++this.musicRequest;
    const playNow = (): void => {
      if (request !== this.musicRequest) return;
      const music = this.sound.add(key, { loop: true, volume: this.audioPreferences.musicVolume });
      this.currentMusic = music;
      music.play();
    };
    if (this.sound.locked) {
      this.sound.once("unlocked", playNow);
    } else {
      playNow();
    }
  }

  private stopMusic(): void {
    this.musicRequest += 1;
    if (this.currentMusic) {
      this.currentMusic.stop();
      this.currentMusic.destroy();
      this.currentMusic = null;
    }
  }

  private sampleInput(): SimulationInput {
    const simulation = this.simulation;
    const noAim = !this.pointerMoved && this.keySpace.isDown && !this.pointerFiring;
    return {
      up: this.keyW.isDown || this.cursors.up.isDown,
      down: this.keyS.isDown || this.cursors.down.isDown,
      left: this.keyA.isDown || this.cursors.left.isDown,
      right: this.keyD.isDown || this.cursors.right.isDown,
      fire: this.pointerFiring || this.keySpace.isDown,
      aimX: noAim ? simulation?.player.x : this.aimX,
      aimY: noAim ? simulation?.player.y : this.aimY,
    };
  }

  private handleSimulationEvents(events: SimulationEvent[]): void {
    for (const event of events) {
      switch (event.type) {
        case "waveStart":
          if (event.wave > 1) this.playSfx("wave-start");
          break;
        case "shot":
          this.playSfx("shoot");
          break;
        case "enemyHit":
          this.enemyFlashUntil.set(event.enemyId, (this.simulation?.tick ?? 0) + 8);
          this.showEffect("impact", event.x, event.y, 160);
          this.playSfx("enemy-hit");
          break;
        case "enemyDefeated":
          this.showEffect("explosion", event.x, event.y, 260);
          this.playSfx("enemy-defeat");
          break;
        case "playerHit":
          this.showEffect("impact", event.x, event.y, 190);
          this.cameras.main.shake(130, 0.003);
          this.playSfx("player-hit");
          break;
        case "gameOver":
          this.finishRun();
          break;
      }
    }
  }

  private finishRun(): void {
    if (!this.simulation || this.mode === "gameover") return;
    this.mode = "gameover";
    this.pointerFiring = false;
    this.stopMusic();
    this.playSfx("game-over");
    const completion = this.simulation.completion;
    if (completion) {
      this.highScore = Math.max(this.highScore, completion.score);
      writeCompletion(completion);
      this.gameOverSummary.setText(
        `SCORE  ${this.formatScore(completion.score)}\nWAVE  ${String(completion.wave).padStart(2, "0")}   •   TICK  ${completion.finalTick}\nSEED  ${completion.seed}`,
      );
    }
    this.setGameOverVisible(true);
    this.updateStatusNode();
  }

  private playSfx(key: string): void {
    if (this.audioPreferences.muted) return;
    this.sound.play(key, { volume: this.audioPreferences.effectsVolume });
  }

  private syncWorldVisuals(): void {
    const simulation = this.simulation;
    if (!simulation) return;

    this.playerSprite.setPosition(simulation.player.x, simulation.player.y);
    this.playerSprite.setRotation(simulation.player.angle);
    const flashing = simulation.tick < simulation.player.invulnerableUntilTick;
    this.playerSprite.setAlpha(flashing && simulation.tick % 6 < 3 ? 0.3 : 1);
    if (flashing) this.playerSprite.setTint(COLORS.danger);
    else this.playerSprite.clearTint();

    const liveBulletIds = new Set(simulation.bullets.map((bullet) => bullet.id));
    for (const [id, bullet] of this.bulletVisuals) {
      if (!liveBulletIds.has(id)) {
        bullet.destroy();
        this.bulletVisuals.delete(id);
      }
    }
    for (const bullet of simulation.bullets) {
      let visual = this.bulletVisuals.get(bullet.id);
      if (!visual) {
        visual = this.add.circle(bullet.x, bullet.y, bullet.radius, COLORS.accent, 1).setDepth(15);
        this.bulletVisuals.set(bullet.id, visual);
      }
      visual.setPosition(bullet.x, bullet.y);
    }

    const liveEnemyIds = new Set(simulation.enemies.map((enemy) => enemy.id));
    for (const [id, visual] of this.enemyVisuals) {
      if (!liveEnemyIds.has(id)) {
        visual.sprite.destroy();
        visual.healthBar.destroy();
        this.enemyVisuals.delete(id);
      }
    }
    for (const enemy of simulation.enemies) {
      let visual = this.enemyVisuals.get(enemy.id);
      if (!visual) {
        visual = {
          sprite: this.add
            .sprite(enemy.x, enemy.y, this.enemyTexture(enemy.kind))
            .setDisplaySize(enemy.radius * 2.2, enemy.radius * 2.2)
            .setDepth(13),
          healthBar: this.add.graphics().setDepth(14),
        };
        this.enemyVisuals.set(enemy.id, visual);
      }
      visual.sprite.setPosition(enemy.x, enemy.y);
      visual.sprite.setDisplaySize(enemy.radius * 2.2, enemy.radius * 2.2);
      const hitFlash = (this.enemyFlashUntil.get(enemy.id) ?? 0) > simulation.tick;
      if (hitFlash) visual.sprite.setTint(COLORS.white);
      else visual.sprite.clearTint();
      visual.healthBar.clear();
      const barWidth = enemy.radius * 2.3;
      const barX = enemy.x - barWidth / 2;
      const barY = enemy.y - enemy.radius - 12;
      visual.healthBar.fillStyle(0x08111f, 0.85).fillRect(barX, barY, barWidth, 4);
      visual.healthBar
        .fillStyle(enemy.kind === "tank" ? COLORS.highlight : COLORS.accent, 1)
        .fillRect(barX, barY, barWidth * (enemy.health / enemy.maxHealth), 4);
    }

    this.reticle.clear();
    this.reticle.lineStyle(1, COLORS.accent, 0.9);
    this.reticle.strokeCircle(this.aimX, this.aimY, 11);
    this.reticle.lineBetween(this.aimX - 17, this.aimY, this.aimX - 5, this.aimY);
    this.reticle.lineBetween(this.aimX + 5, this.aimY, this.aimX + 17, this.aimY);
    this.reticle.lineBetween(this.aimX, this.aimY - 17, this.aimX, this.aimY - 5);
    this.reticle.lineBetween(this.aimX, this.aimY + 5, this.aimX, this.aimY + 17);
  }

  private updateHud(): void {
    if (!this.simulation) return;
    this.scoreText.setText(`SCORE\n${this.formatScore(this.simulation.score)}`);
    this.waveText.setText(`WAVE\n${String(this.simulation.wave).padStart(2, "0")}`);
    this.seedText.setText(`SEED  ${this.simulation.seed}`);
    this.healthLabel.setText(`HULL  ${this.simulation.player.health}/${this.simulation.player.maxHealth}`);
    for (let index = 0; index < this.heartIcons.length; index += 1) {
      this.heartIcons[index].setAlpha(index < this.simulation.player.health ? 1 : 0.24);
    }
    this.pauseButton.label.setText(this.mode === "paused" ? "RESUME" : "PAUSE");
    this.updateAudioLabels();
  }

  private updateStatusNode(): void {
    if (!this.statusNode) return;
    const score = this.simulation?.score ?? 0;
    const wave = this.simulation?.wave ?? 0;
    this.statusNode.dataset.state = this.mode;
    this.statusNode.dataset.score = String(score);
    this.statusNode.dataset.wave = String(wave);
    this.statusNode.dataset.muted = String(this.audioPreferences.muted);
    this.statusNode.textContent = `${this.mode} score ${score} wave ${wave}`;
  }

  private showEffect(atlasKey: "impact" | "explosion", x: number, y: number, duration: number): void {
    const sprite = this.add.sprite(x, y, atlasKey, "frame-0").setDisplaySize(52, 52).setDepth(20);
    this.effects.push({ sprite, elapsed: 0, duration, atlasKey });
  }

  private updateEffects(delta: number): void {
    for (let index = this.effects.length - 1; index >= 0; index -= 1) {
      const effect = this.effects[index];
      effect.elapsed += delta;
      const progress = Math.min(1, effect.elapsed / effect.duration);
      effect.sprite.setFrame(`frame-${Math.min(3, Math.floor(progress * 4))}`);
      effect.sprite.setAlpha(1 - progress);
      effect.sprite.setScale(0.75 + progress * 0.85);
      if (progress >= 1) {
        effect.sprite.destroy();
        this.effects.splice(index, 1);
      }
    }
  }

  private enemyTexture(kind: EnemyKind): string {
    if (kind === "tank") return "enemy-tank";
    if (kind === "striker") return "enemy-striker";
    return "enemy-chaser";
  }

  private setButtonVisible(button: GameButton, visible: boolean): void {
    button.background.setVisible(visible).setActive(visible);
    button.label.setVisible(visible).setActive(visible);
  }

  private setPauseVisible(visible: boolean): void {
    this.pauseShade.setVisible(visible);
    this.pausePanel.setVisible(visible);
    this.pauseTitle.setVisible(visible);
    this.pauseCopy.setVisible(visible);
    this.setButtonVisible(this.pauseResumeButton, visible);
    this.setButtonVisible(this.pauseMuteButton, visible);
    this.setButtonVisible(this.pauseMenuButton, visible);
  }

  private setGameOverVisible(visible: boolean): void {
    this.gameOverShade.setVisible(visible);
    this.gameOverPanel.setVisible(visible);
    this.gameOverTitle.setVisible(visible);
    this.gameOverSummary.setVisible(visible);
    this.gameOverHint.setVisible(visible);
    this.setButtonVisible(this.restartButton, visible);
    this.setButtonVisible(this.gameOverMenuButton, visible);
  }

  private clearWorldVisuals(): void {
    for (const bullet of this.bulletVisuals.values()) bullet.destroy();
    this.bulletVisuals.clear();
    for (const visual of this.enemyVisuals.values()) {
      visual.sprite.destroy();
      visual.healthBar.destroy();
    }
    this.enemyVisuals.clear();
    for (const effect of this.effects) effect.sprite.destroy();
    this.effects = [];
    this.enemyFlashUntil.clear();
  }

  private formatScore(score: number): string {
    return String(score).padStart(6, "0");
  }
}

new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  backgroundColor: COLORS.background,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
  },
  render: {
    antialias: true,
    roundPixels: true,
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
  audio: {
    disableWebAudio: false,
  },
  scene: VectorSiegeScene,
});
