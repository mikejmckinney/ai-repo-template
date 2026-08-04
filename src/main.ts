import Phaser from "phaser";
import {
  ArenaSimulation,
  SIMULATION_DT,
  type CompletedGameRecord,
  type EnemyKind,
  type InputFrame,
  type SimulationEvent,
  type SimulationSnapshot,
} from "./shared-simulation/simulation";

const WIDTH = 1280;
const HEIGHT = 720;
const ASSET_ROOT = "/benchmark-assets/vector-siege";
const VISUAL_ROOT = `${ASSET_ROOT}/visuals`;
const AUDIO_ROOT = `${ASSET_ROOT}/audio`;

const COLORS = {
  accent: 0x49dcb1,
  accentHex: "#49dcb1",
  background: 0x08111f,
  backgroundHex: "#08111f",
  danger: 0xff4f78,
  dangerHex: "#ff4f78",
  highlight: 0xf6c453,
  highlightHex: "#f6c453",
  muted: 0x61728b,
  mutedHex: "#61728b",
  ink: 0xe8f3f2,
  inkHex: "#e8f3f2",
};

const STORAGE_KEYS = {
  highScore: "vector-siege.high-score",
  preferences: "vector-siege.audio-preferences",
};

interface AudioPreferences {
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
}

const DEFAULT_PREFERENCES: AudioPreferences = {
  musicVolume: 0.42,
  effectsVolume: 0.62,
  muted: false,
};

const textStyle = (fontSize: number, color = "#e8f3f2", extra: Record<string, unknown> = {}): Phaser.Types.GameObjects.Text.TextStyle => ({
  fontFamily: "Arial, Helvetica, sans-serif",
  fontSize: `${fontSize}px`,
  color,
  ...extra,
});

const clamp = (value: number, min: number, max: number): number => Math.min(max, Math.max(min, value));

const safeParsePreferences = (): AudioPreferences => {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEYS.preferences);
    if (!stored) {
      return { ...DEFAULT_PREFERENCES };
    }
    const parsed = JSON.parse(stored) as Partial<AudioPreferences>;
    return {
      musicVolume: clamp(Number(parsed.musicVolume ?? DEFAULT_PREFERENCES.musicVolume), 0, 1),
      effectsVolume: clamp(Number(parsed.effectsVolume ?? DEFAULT_PREFERENCES.effectsVolume), 0, 1),
      muted: Boolean(parsed.muted),
    };
  } catch {
    return { ...DEFAULT_PREFERENCES };
  }
};

const savePreferences = (preferences: AudioPreferences): void => {
  try {
    window.localStorage.setItem(STORAGE_KEYS.preferences, JSON.stringify(preferences));
  } catch {
    // Storage is optional in private browsing and evaluator sandboxes.
  }
};

const readHighScore = (): number => {
  try {
    return Math.max(0, Number(window.localStorage.getItem(STORAGE_KEYS.highScore) ?? 0));
  } catch {
    return 0;
  }
};

const writeHighScore = (score: number): void => {
  try {
    window.localStorage.setItem(STORAGE_KEYS.highScore, String(score));
  } catch {
    // Storage is optional in private browsing and evaluator sandboxes.
  }
};

class ArenaScene extends Phaser.Scene {
  private simulation!: ArenaSimulation;
  private readonly seed: string;
  private runStarted = false;
  private accumulator = 0;
  private preferences = safeParsePreferences();
  private highScore = readHighScore();
  private music?: Phaser.Sound.BaseSound;

  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private pauseKey!: Phaser.Input.Keyboard.Key;
  private restartKey!: Phaser.Input.Keyboard.Key;

  private menuObjects: Phaser.GameObjects.GameObject[] = [];
  private hudObjects: Phaser.GameObjects.GameObject[] = [];
  private pauseObjects: Phaser.GameObjects.GameObject[] = [];
  private gameOverObjects: Phaser.GameObjects.GameObject[] = [];
  private enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private projectileSprites = new Map<number, Phaser.GameObjects.Arc>();

  private arenaBorder!: Phaser.GameObjects.Graphics;
  private arenaBackground!: Phaser.GameObjects.Image;
  private enemyHealthBars!: Phaser.GameObjects.Graphics;
  private crosshair!: Phaser.GameObjects.Graphics;
  private hitFlash!: Phaser.GameObjects.Rectangle;
  private playerSprite!: Phaser.GameObjects.Image;

  private scoreText!: Phaser.GameObjects.Text;
  private waveText!: Phaser.GameObjects.Text;
  private healthText!: Phaser.GameObjects.Text;
  private highScoreText!: Phaser.GameObjects.Text;
  private seedText!: Phaser.GameObjects.Text;
  private statusText!: Phaser.GameObjects.Text;
  private soundText!: Phaser.GameObjects.Text;
  private menuSoundText!: Phaser.GameObjects.Text;
  private musicVolumeText!: Phaser.GameObjects.Text;
  private effectsVolumeText!: Phaser.GameObjects.Text;
  private pauseTitle!: Phaser.GameObjects.Text;
  private gameOverSummary!: Phaser.GameObjects.Text;
  private stateNode?: HTMLElement;

  constructor() {
    super("ArenaScene");
    const urlSeed = new URLSearchParams(window.location.search).get("seed");
    this.seed = urlSeed || "STAGE-1-ALPHA";
  }

  preload(): void {
    this.load.image("menu-background", `${VISUAL_ROOT}/menu-background.webp`);
    this.load.image("arena-background", `${VISUAL_ROOT}/arena-background.webp`);
    this.load.image("logo", `${VISUAL_ROOT}/logo.webp`);
    this.load.image("player", `${VISUAL_ROOT}/player.webp`);
    this.load.image("enemy-chaser", `${VISUAL_ROOT}/enemies/chaser.webp`);
    this.load.image("enemy-striker", `${VISUAL_ROOT}/enemies/striker.webp`);
    this.load.image("enemy-tank", `${VISUAL_ROOT}/enemies/tank.webp`);
    this.load.image("heart", `${VISUAL_ROOT}/ui/heart.webp`);
    this.load.image("score-icon", `${VISUAL_ROOT}/ui/score.webp`);
    this.load.image("wave-icon", `${VISUAL_ROOT}/ui/wave.webp`);
    this.load.atlas(
      "explosion-atlas",
      `${VISUAL_ROOT}/effects/explosion-atlas.webp`,
      `${VISUAL_ROOT}/effects/explosion-atlas.json`,
    );
    this.load.atlas(
      "impact-atlas",
      `${VISUAL_ROOT}/effects/impact-atlas.webp`,
      `${VISUAL_ROOT}/effects/impact-atlas.json`,
    );

    this.load.audio("menu-theme", `${AUDIO_ROOT}/menu-theme.mp3`);
    this.load.audio("gameplay-loop", `${AUDIO_ROOT}/gameplay-loop.mp3`);
    this.load.audio("shoot", `${AUDIO_ROOT}/shoot.wav`, { instances: 5 });
    this.load.audio("enemy-hit", `${AUDIO_ROOT}/enemy-hit.wav`, { instances: 4 });
    this.load.audio("enemy-defeat", `${AUDIO_ROOT}/enemy-defeat.wav`, { instances: 4 });
    this.load.audio("player-hit", `${AUDIO_ROOT}/player-hit.wav`, { instances: 3 });
    this.load.audio("wave-start", `${AUDIO_ROOT}/wave-start.wav`);
    this.load.audio("game-over", `${AUDIO_ROOT}/game-over.wav`);
  }

  create(): void {
    this.simulation = new ArenaSimulation({ seed: this.seed, width: WIDTH, height: HEIGHT });
    this.stateNode = document.createElement("div");
    this.stateNode.id = "vector-siege-state";
    this.stateNode.className = "visually-hidden";
    this.stateNode.setAttribute("aria-live", "polite");
    document.getElementById("game")?.appendChild(this.stateNode);
    this.updateStateNode("menu");
    this.createInput();
    this.createFxLayers();
    this.createHud();
    this.createPauseOverlay();
    this.createGameOverOverlay();
    this.createMenu();
    this.setHudVisible(false);
    this.setPauseVisible(false);
    this.setGameOverVisible(false);
    this.applyMute();
    this.playMusic("menu-theme");

    this.input.on("pointerup", (pointer: Phaser.Input.Pointer) => {
      this.unlockAudio();
      if (!this.runStarted && pointer.x >= 380 && pointer.x <= 860 && pointer.y >= 350 && pointer.y <= 500) {
        this.startRun();
      }
    });
    this.input.keyboard?.on("keydown", () => this.unlockAudio());
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.cleanupAudio());
  }

  update(_time: number, delta: number): void {
    if (this.runStarted && this.simulation.phase === "running") {
      this.accumulator += Math.min(delta, 100) / 1000;
      let steps = 0;
      while (this.accumulator >= SIMULATION_DT && steps < 8) {
        this.simulation.step(this.readInput());
        this.processSimulationEvents(this.simulation.events);
        this.accumulator -= SIMULATION_DT;
        steps += 1;
      }
    }

    if (this.runStarted) {
      this.renderGame(this.simulation.snapshot());
      this.renderCrosshair();
    }
  }

  private createInput(): void {
    const keyboard = this.input.keyboard!;
    this.cursors = keyboard.createCursorKeys();
    this.keys = keyboard.addKeys("W,A,S,D,SPACE") as Record<string, Phaser.Input.Keyboard.Key>;
    this.pauseKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.P);
    this.restartKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.R);
    keyboard.addCapture(["SPACE", "UP", "DOWN", "LEFT", "RIGHT"]);

    keyboard.on("keydown-P", () => this.togglePause());
    keyboard.on("keydown-ESC", () => this.togglePause());
    keyboard.on("keydown-SPACE", () => {
      if (!this.runStarted || this.simulation.phase === "gameover") {
        this.startRun();
      }
    });
    keyboard.on("keydown-R", () => {
      if (this.runStarted && this.simulation.phase === "gameover") {
        this.startRun();
      }
    });
    keyboard.on("keydown-ENTER", () => {
      if (!this.runStarted || this.simulation.phase === "gameover") {
        this.startRun();
      }
    });
  }

  private createFxLayers(): void {
    this.arenaBackground = this.add.image(WIDTH / 2, HEIGHT / 2, "arena-background").setDepth(-1).setVisible(false);
    this.arenaBorder = this.add.graphics().setDepth(4);
    this.arenaBorder.lineStyle(2, COLORS.accent, 0.45);
    this.arenaBorder.strokeRoundedRect(34, 34, WIDTH - 68, HEIGHT - 68, 18);
    this.arenaBorder.lineStyle(1, COLORS.muted, 0.28);
    this.arenaBorder.strokeRoundedRect(46, 46, WIDTH - 92, HEIGHT - 92, 13);

    this.enemyHealthBars = this.add.graphics().setDepth(35);
    this.crosshair = this.add.graphics().setDepth(60);
    this.hitFlash = this.add.rectangle(WIDTH / 2, HEIGHT / 2, WIDTH, HEIGHT, COLORS.danger, 0).setDepth(80);
  }

  private createHud(): void {
    const topBar = this.add.rectangle(WIDTH / 2, 43, WIDTH - 72, 60, COLORS.background, 0.9).setDepth(50);
    topBar.setStrokeStyle(1, COLORS.muted, 0.35);
    this.hudObjects.push(topBar);

    const scoreIcon = this.add.image(66, 43, "score-icon").setScale(0.56).setDepth(51);
    const waveIcon = this.add.image(338, 43, "wave-icon").setScale(0.56).setDepth(51);
    this.hudObjects.push(scoreIcon, waveIcon);

    this.scoreText = this.add.text(93, 27, "SCORE 000000", textStyle(17, COLORS.highlightHex, { fontStyle: "bold" })).setDepth(51);
    this.waveText = this.add.text(365, 27, "WAVE 01", textStyle(17, COLORS.accentHex, { fontStyle: "bold" })).setDepth(51);
    this.healthText = this.add.text(568, 27, "HULL", textStyle(12, COLORS.mutedHex, { fontStyle: "bold", letterSpacing: "2px" })).setDepth(51);
    this.statusText = this.add.text(820, 27, "SECTOR 01 // LIVE", textStyle(15, COLORS.accentHex, { fontStyle: "bold" })).setDepth(51);
    this.soundText = this.add.text(1122, 29, "SOUND ON", textStyle(12, COLORS.inkHex, { fontStyle: "bold" })).setDepth(51);
    this.hudObjects.push(this.scoreText, this.waveText, this.healthText, this.statusText, this.soundText);

    const soundButton = this.add.rectangle(1164, 43, 132, 42, COLORS.muted, 0.18).setDepth(50).setInteractive({ useHandCursor: true });
    soundButton.setStrokeStyle(1, COLORS.muted, 0.5);
    soundButton.on("pointerup", () => this.toggleMute());
    this.hudObjects.push(soundButton);

    const pauseButton = this.add.rectangle(1024, 43, 106, 42, COLORS.accent, 0.13).setDepth(50).setInteractive({ useHandCursor: true });
    pauseButton.setStrokeStyle(1, COLORS.accent, 0.45);
    const pauseLabel = this.add.text(1024, 35, "PAUSE  [P]", textStyle(12, COLORS.accentHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(51);
    pauseButton.on("pointerup", () => this.togglePause());
    this.hudObjects.push(pauseButton, pauseLabel);

    for (let index = 0; index < 5; index += 1) {
      const heart = this.add.image(630 + index * 28, 44, "heart").setScale(0.42).setDepth(51);
      this.hudObjects.push(heart);
    }
  }

  private createPauseOverlay(): void {
    const veil = this.add.rectangle(WIDTH / 2, HEIGHT / 2, WIDTH, HEIGHT, COLORS.background, 0.82).setDepth(70);
    const panel = this.add.rectangle(WIDTH / 2, HEIGHT / 2, 470, 250, COLORS.background, 0.98).setDepth(71);
    panel.setStrokeStyle(2, COLORS.accent, 0.65);
    this.pauseTitle = this.add.text(WIDTH / 2, 284, "RUN PAUSED", textStyle(36, COLORS.accentHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(72);
    const body = this.add.text(WIDTH / 2, 344, "The grid is holding.\nPress P or click below to resume.", textStyle(17, COLORS.inkHex, { align: "center", lineSpacing: 9 })).setOrigin(0.5).setDepth(72);
    const resumeButton = this.add.rectangle(WIDTH / 2, 425, 210, 52, COLORS.accent, 0.9).setDepth(72).setInteractive({ useHandCursor: true });
    const resumeLabel = this.add.text(WIDTH / 2, 414, "RESUME RUN", textStyle(15, COLORS.backgroundHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(73);
    resumeButton.on("pointerup", () => this.togglePause());
    this.pauseObjects.push(veil, panel, this.pauseTitle, body, resumeButton, resumeLabel);
  }

  private createGameOverOverlay(): void {
    const veil = this.add.rectangle(WIDTH / 2, HEIGHT / 2, WIDTH, HEIGHT, COLORS.background, 0.86).setDepth(70);
    const panel = this.add.rectangle(WIDTH / 2, HEIGHT / 2, 540, 320, COLORS.background, 0.98).setDepth(71);
    panel.setStrokeStyle(2, COLORS.danger, 0.75);
    const title = this.add.text(WIDTH / 2, 250, "SIGNAL LOST", textStyle(42, COLORS.dangerHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(72);
    this.gameOverSummary = this.add.text(WIDTH / 2, 329, "", textStyle(17, COLORS.inkHex, { align: "center", lineSpacing: 9 })).setOrigin(0.5).setDepth(72);
    const restartButton = this.add.rectangle(WIDTH / 2, 448, 250, 56, COLORS.danger, 0.9).setDepth(72).setInteractive({ useHandCursor: true });
    const restartLabel = this.add.text(WIDTH / 2, 437, "RESTART RUN", textStyle(16, COLORS.backgroundHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(73);
    restartButton.on("pointerup", () => this.startRun());
    this.gameOverObjects.push(veil, panel, title, this.gameOverSummary, restartButton, restartLabel);
  }

  private createMenu(): void {
    const background = this.add.image(WIDTH / 2, HEIGHT / 2, "menu-background").setDepth(0);
    const shade = this.add.rectangle(WIDTH / 2, HEIGHT / 2, WIDTH, HEIGHT, COLORS.background, 0.45).setDepth(1);
    const accentRail = this.add.rectangle(78, HEIGHT / 2, 4, 470, COLORS.accent, 0.9).setDepth(2);
    const stageTag = this.add.text(106, 88, "VECTOR SIEGE  //  STAGE 01", textStyle(14, COLORS.accentHex, { fontStyle: "bold", letterSpacing: "2px" })).setDepth(2);
    const logo = this.add.image(640, 164, "logo").setScale(0.72).setDepth(2);
    const title = this.add.text(640, 276, "VECTOR SIEGE", textStyle(42, COLORS.inkHex, { fontStyle: "bold", letterSpacing: 7 })).setOrigin(0.5).setDepth(2);
    const subtitle = this.add.text(640, 324, "LOCK THE GRID. HOLD THE LINE.", textStyle(14, COLORS.mutedHex, { fontStyle: "bold", letterSpacing: "3px" })).setOrigin(0.5).setDepth(2);

    const startButton = this.add.rectangle(640, 418, 320, 68, COLORS.accent, 0.94).setDepth(2).setInteractive({ useHandCursor: true });
    startButton.setStrokeStyle(2, COLORS.ink, 0.32);
    const startLabel = this.add.text(640, 403, "START RUN", textStyle(19, COLORS.backgroundHex, { fontStyle: "bold", letterSpacing: "2px" })).setOrigin(0.5).setDepth(3);
    const startHint = this.add.text(640, 430, "ENTER / SPACE", textStyle(11, COLORS.backgroundHex, { fontStyle: "bold", letterSpacing: "2px" })).setOrigin(0.5).setDepth(3);
    startButton.on("pointerup", () => this.startRun());

    const controlsPanel = this.add.rectangle(640, 566, 700, 92, COLORS.background, 0.74).setDepth(1);
    controlsPanel.setStrokeStyle(1, COLORS.muted, 0.45);
    const controls = this.add.text(640, 541, "WASD / ARROWS  MOVE      POINTER  AIM      CLICK / SPACE  FIRE", textStyle(13, COLORS.inkHex, { fontStyle: "bold", letterSpacing: 1 })).setOrigin(0.5).setDepth(2);
    const controlHint = this.add.text(640, 578, "P  PAUSE      SURVIVE THE WAVE      NO SIGNAL LEFT BEHIND", textStyle(12, COLORS.mutedHex, { fontStyle: "bold", letterSpacing: "1px" })).setOrigin(0.5).setDepth(2);

    const soundPanel = this.add.rectangle(1040, 564, 300, 156, COLORS.background, 0.76).setDepth(1);
    soundPanel.setStrokeStyle(1, COLORS.muted, 0.45);
    const soundHeading = this.add.text(918, 502, "AUDIO LINK", textStyle(12, COLORS.accentHex, { fontStyle: "bold", letterSpacing: "2px" })).setDepth(2);
    const muteButton = this.add.rectangle(1040, 527, 220, 38, COLORS.muted, 0.2).setDepth(2).setInteractive({ useHandCursor: true });
    muteButton.setStrokeStyle(1, COLORS.muted, 0.5);
    this.menuSoundText = this.add.text(1040, 517, "SOUND ON", textStyle(12, COLORS.inkHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(3);
    muteButton.on("pointerup", () => this.toggleMute());
    const musicDown = this.add.rectangle(988, 583, 44, 32, COLORS.muted, 0.22).setDepth(2).setInteractive({ useHandCursor: true });
    const musicUp = this.add.rectangle(1092, 583, 44, 32, COLORS.muted, 0.22).setDepth(2).setInteractive({ useHandCursor: true });
    const effectsDown = this.add.rectangle(988, 630, 44, 32, COLORS.muted, 0.22).setDepth(2).setInteractive({ useHandCursor: true });
    const effectsUp = this.add.rectangle(1092, 630, 44, 32, COLORS.muted, 0.22).setDepth(2).setInteractive({ useHandCursor: true });
    [musicDown, musicUp, effectsDown, effectsUp].forEach((button) => button.setStrokeStyle(1, COLORS.muted, 0.4));
    musicDown.on("pointerup", () => this.changeVolume("music", -0.1));
    musicUp.on("pointerup", () => this.changeVolume("music", 0.1));
    effectsDown.on("pointerup", () => this.changeVolume("effects", -0.1));
    effectsUp.on("pointerup", () => this.changeVolume("effects", 0.1));
    const musicDownLabel = this.add.text(988, 575, "−", textStyle(20, COLORS.inkHex)).setOrigin(0.5).setDepth(3);
    const musicUpLabel = this.add.text(1092, 575, "+", textStyle(20, COLORS.inkHex)).setOrigin(0.5).setDepth(3);
    const effectsDownLabel = this.add.text(988, 622, "−", textStyle(20, COLORS.inkHex)).setOrigin(0.5).setDepth(3);
    const effectsUpLabel = this.add.text(1092, 622, "+", textStyle(20, COLORS.inkHex)).setOrigin(0.5).setDepth(3);
    this.musicVolumeText = this.add.text(1040, 575, "MUSIC 42%", textStyle(11, COLORS.inkHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(3);
    this.effectsVolumeText = this.add.text(1040, 622, "EFFECTS 62%", textStyle(11, COLORS.inkHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(3);

    this.highScoreText = this.add.text(106, 640, "BEST RUN  000000", textStyle(14, COLORS.highlightHex, { fontStyle: "bold", letterSpacing: "1px" })).setDepth(2);
    const footer = this.add.text(106, 674, "DETERMINISTIC SIGNAL  //  SEED-LOCKED COMBAT", textStyle(11, COLORS.mutedHex, { fontStyle: "bold", letterSpacing: "1px" })).setDepth(2);

    this.menuObjects.push(
      background,
      shade,
      accentRail,
      stageTag,
      logo,
      title,
      subtitle,
      startButton,
      startLabel,
      startHint,
      controlsPanel,
      controls,
      controlHint,
      soundPanel,
      soundHeading,
      muteButton,
      this.menuSoundText,
      musicDown,
      musicUp,
      effectsDown,
      effectsUp,
      musicDownLabel,
      musicUpLabel,
      effectsDownLabel,
      effectsUpLabel,
      this.musicVolumeText,
      this.effectsVolumeText,
      this.highScoreText,
      footer,
    );
    this.updateMenuLabels();
  }

  private startRun(): void {
    this.unlockAudio();
    this.simulation.restart(this.seed);
    this.runStarted = true;
    this.accumulator = 0;
    this.setMenuVisible(false);
    this.setHudVisible(true);
    this.setPauseVisible(false);
    this.setGameOverVisible(false);
    this.playMusic("gameplay-loop");
    this.playSfx("wave-start");
    this.renderGame(this.simulation.snapshot());
  }

  private togglePause(): void {
    if (!this.runStarted || this.simulation.phase === "gameover") {
      return;
    }
    if (this.simulation.phase === "paused") {
      this.simulation.resume();
      this.setPauseVisible(false);
      this.music?.resume();
      this.statusText.setText("SECTOR 01 // LIVE");
    } else {
      this.simulation.pause();
      this.setPauseVisible(true);
      this.music?.pause();
      this.statusText.setText("SECTOR 01 // HOLD");
    }
  }

  private readInput(): InputFrame {
    const moveX = (this.keys.D?.isDown || this.cursors.right.isDown ? 1 : 0) - (this.keys.A?.isDown || this.cursors.left.isDown ? 1 : 0);
    const moveY = (this.keys.S?.isDown || this.cursors.down.isDown ? 1 : 0) - (this.keys.W?.isDown || this.cursors.up.isDown ? 1 : 0);
    const pointer = this.input.activePointer;
    const aimX = Number.isFinite(pointer.worldX) ? pointer.worldX : pointer.x;
    const aimY = Number.isFinite(pointer.worldY) ? pointer.worldY : pointer.y;
    return {
      moveX,
      moveY,
      aimX,
      aimY,
      fire: pointer.isDown || this.keys.SPACE?.isDown === true,
    };
  }

  private processSimulationEvents(events: readonly SimulationEvent[]): void {
    for (const event of events) {
      if (event.type === "shot") {
        this.playSfx("shoot");
      } else if (event.type === "enemy-hit") {
        this.playSfx("enemy-hit");
        this.flashEnemy(event.enemyKind);
        this.spawnEffect("impact-atlas", event.x, event.y, 0.8);
      } else if (event.type === "enemy-defeat") {
        this.playSfx("enemy-defeat");
        this.spawnEffect("explosion-atlas", event.x, event.y, 1.0);
        this.spawnScorePopup(event.x, event.y, event.score ?? 0);
      } else if (event.type === "player-hit") {
        this.playSfx("player-hit");
        this.playerSprite.setTint(COLORS.danger);
        this.tweens.add({
          targets: this.playerSprite,
          alpha: 0.35,
          duration: 80,
          yoyo: true,
          repeat: 3,
          onComplete: () => {
            this.playerSprite.clearTint();
            this.playerSprite.setAlpha(1);
          },
        });
        this.hitFlash.setAlpha(0.23);
        this.tweens.add({ targets: this.hitFlash, alpha: 0, duration: 260 });
      } else if (event.type === "wave-start" && this.runStarted) {
        this.playSfx("wave-start");
      } else if (event.type === "game-over") {
        this.showGameOver(this.simulation.snapshot().completedGame);
      }
    }
  }

  private renderGame(snapshot: SimulationSnapshot): void {
    this.playerSprite ??= this.add.image(snapshot.player.x, snapshot.player.y, "player").setDisplaySize(64, 64).setDepth(20);
    this.playerSprite.setPosition(snapshot.player.x, snapshot.player.y);
    const aim = this.input.activePointer;
    this.playerSprite.setRotation(Math.atan2((aim.worldY ?? aim.y) - snapshot.player.y, (aim.worldX ?? aim.x) - snapshot.player.x) + Math.PI / 4);
    this.playerSprite.setAlpha(snapshot.player.invulnerableTicks > 0 && snapshot.tick % 8 < 4 ? 0.42 : 1);

    const aliveIds = new Set<number>();
    for (const enemy of snapshot.enemies) {
      aliveIds.add(enemy.id);
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.add.image(enemy.x, enemy.y, this.enemyTexture(enemy.kind)).setDepth(18);
        sprite.setDisplaySize(enemy.kind === "tank" ? 76 : enemy.kind === "striker" ? 58 : 64, enemy.kind === "tank" ? 76 : enemy.kind === "striker" ? 58 : 64);
        this.enemySprites.set(enemy.id, sprite);
      }
      sprite.setPosition(enemy.x, enemy.y);
      sprite.setRotation(Math.atan2(snapshot.player.y - enemy.y, snapshot.player.x - enemy.x) + Math.PI / 4);
      sprite.setAlpha(snapshot.player.invulnerableTicks > 0 ? 0.96 : 1);
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!aliveIds.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
      }
    }

    const projectileIds = new Set<number>();
    for (const projectile of snapshot.projectiles) {
      projectileIds.add(projectile.id);
      let sprite = this.projectileSprites.get(projectile.id);
      if (!sprite) {
        sprite = this.add.circle(projectile.x, projectile.y, 5, COLORS.accent, 1).setDepth(19);
        sprite.setStrokeStyle(2, COLORS.ink, 0.8);
        this.projectileSprites.set(projectile.id, sprite);
      }
      sprite.setPosition(projectile.x, projectile.y);
    }
    for (const [id, sprite] of this.projectileSprites) {
      if (!projectileIds.has(id)) {
        sprite.destroy();
        this.projectileSprites.delete(id);
      }
    }

    this.enemyHealthBars.clear();
    for (const enemy of snapshot.enemies) {
      if (enemy.maxHealth <= 1) {
        continue;
      }
      const barWidth = 56;
      const ratio = clamp(enemy.health / enemy.maxHealth, 0, 1);
      this.enemyHealthBars.fillStyle(COLORS.background, 0.9);
      this.enemyHealthBars.fillRoundedRect(enemy.x - barWidth / 2, enemy.y - enemy.radius - 13, barWidth, 6, 3);
      this.enemyHealthBars.fillStyle(COLORS.highlight, 1);
      this.enemyHealthBars.fillRoundedRect(enemy.x - barWidth / 2 + 1, enemy.y - enemy.radius - 12, (barWidth - 2) * ratio, 4, 2);
    }

    this.scoreText.setText(`SCORE ${String(snapshot.score).padStart(6, "0")}`);
    this.waveText.setText(`WAVE ${String(snapshot.wave).padStart(2, "0")}`);
    this.healthText.setText(`HULL ${snapshot.player.health}/${snapshot.player.maxHealth}`);
    this.statusText.setText(snapshot.phase === "paused" ? "SECTOR 01 // HOLD" : `SECTOR ${String(snapshot.wave).padStart(2, "0")} // LIVE`);
    const hearts = this.hudObjects.filter((object) => object instanceof Phaser.GameObjects.Image).slice(-5) as Phaser.GameObjects.Image[];
    hearts.forEach((heart, index) => heart.setAlpha(index < snapshot.player.health ? 1 : 0.18));
    this.updateStateNode(snapshot.phase, snapshot);
  }

  private renderCrosshair(): void {
    const pointer = this.input.activePointer;
    const x = clamp(pointer.worldX ?? pointer.x, 20, WIDTH - 20);
    const y = clamp(pointer.worldY ?? pointer.y, 20, HEIGHT - 20);
    this.crosshair.clear();
    this.crosshair.lineStyle(2, COLORS.accent, 0.9);
    this.crosshair.strokeCircle(x, y, 13);
    this.crosshair.lineBetween(x - 21, y, x - 7, y);
    this.crosshair.lineBetween(x + 7, y, x + 21, y);
    this.crosshair.lineBetween(x, y - 21, x, y - 7);
    this.crosshair.lineBetween(x, y + 7, x, y + 21);
    this.crosshair.fillStyle(COLORS.highlight, 1);
    this.crosshair.fillCircle(x, y, 2);
  }

  private enemyTexture(kind: EnemyKind): string {
    return kind === "chaser" ? "enemy-chaser" : kind === "striker" ? "enemy-striker" : "enemy-tank";
  }

  private flashEnemy(kind?: EnemyKind): void {
    if (!kind) {
      return;
    }
    for (const enemy of this.simulation.snapshot().enemies) {
      if (enemy.kind !== kind) {
        continue;
      }
      const sprite = this.enemySprites.get(enemy.id);
      if (sprite) {
        sprite.setTint(COLORS.ink);
        this.time.delayedCall(110, () => sprite.clearTint());
      }
      break;
    }
  }

  private spawnEffect(key: "explosion-atlas" | "impact-atlas", x: number, y: number, scale: number): void {
    const sprite = this.add.image(x, y, key, "frame-0").setScale(scale).setDepth(30);
    let frame = 0;
    this.time.addEvent({
      delay: 52,
      repeat: 3,
      callback: () => {
        frame += 1;
        if (frame > 3) {
          sprite.destroy();
          return;
        }
        sprite.setFrame(`frame-${frame}`);
      },
    });
  }

  private spawnScorePopup(x: number, y: number, score: number): void {
    const popup = this.add.text(x, y - 32, `+${score}`, textStyle(15, COLORS.highlightHex, { fontStyle: "bold" })).setOrigin(0.5).setDepth(40);
    this.tweens.add({
      targets: popup,
      y: y - 70,
      alpha: 0,
      duration: 650,
      ease: "Cubic.easeOut",
      onComplete: () => popup.destroy(),
    });
  }

  private showGameOver(record: CompletedGameRecord | null): void {
    if (!record) {
      return;
    }
    this.music?.stop();
    this.playSfx("game-over");
    if (record.score > this.highScore) {
      this.highScore = record.score;
      writeHighScore(this.highScore);
    }
    this.gameOverSummary.setText([
      `SCORE  ${String(record.score).padStart(6, "0")}      WAVE  ${String(record.wave).padStart(2, "0")}`,
      `SEED  ${record.seed}`,
      `FINAL SIM TICK  ${record.finalTick}`,
    ]);
    this.setGameOverVisible(true);
    this.setHudVisible(false);
    this.statusText.setText("SIGNAL LOST");
    this.updateStateNode("gameover", this.simulation.snapshot());
  }

  private toggleMute(): void {
    this.preferences.muted = !this.preferences.muted;
    savePreferences(this.preferences);
    this.applyMute();
    this.updateMenuLabels();
    this.updateStateNode(this.runStarted ? this.simulation.phase : "menu", this.runStarted ? this.simulation.snapshot() : undefined);
  }

  private applyMute(): void {
    this.sound.setMute(this.preferences.muted);
  }

  private changeVolume(kind: "music" | "effects", amount: number): void {
    if (kind === "music") {
      this.preferences.musicVolume = clamp(this.preferences.musicVolume + amount, 0, 1);
      this.playMusic(this.runStarted ? "gameplay-loop" : "menu-theme");
    } else {
      this.preferences.effectsVolume = clamp(this.preferences.effectsVolume + amount, 0, 1);
    }
    savePreferences(this.preferences);
    this.updateMenuLabels();
  }

  private updateMenuLabels(): void {
    const soundLabel = this.preferences.muted ? "MUTED" : "SOUND ON";
    this.soundText?.setText(soundLabel);
    this.menuSoundText?.setText(soundLabel);
    this.musicVolumeText?.setText(`MUSIC ${Math.round(this.preferences.musicVolume * 100)}%`);
    this.effectsVolumeText?.setText(`EFFECTS ${Math.round(this.preferences.effectsVolume * 100)}%`);
    this.highScoreText?.setText(`BEST RUN  ${String(this.highScore).padStart(6, "0")}`);
  }

  private playMusic(key: "menu-theme" | "gameplay-loop"): void {
    this.music?.stop();
    this.music?.destroy();
    this.music = this.sound.add(key, { loop: true, volume: this.preferences.musicVolume });
    this.music.play();
  }

  private playSfx(key: "shoot" | "enemy-hit" | "enemy-defeat" | "player-hit" | "wave-start" | "game-over"): void {
    if (this.preferences.muted) {
      return;
    }
    this.sound.play(key, { volume: this.preferences.effectsVolume });
  }

  private unlockAudio(): void {
    const soundManager = this.sound as Phaser.Sound.BaseSoundManager & { context?: AudioContext };
    const context = soundManager.context;
    if (context?.state === "suspended") {
      void context.resume().catch(() => undefined);
    }
  }

  private cleanupAudio(): void {
    this.music?.stop();
    this.music?.destroy();
  }

  private updateStateNode(phase: "menu" | "running" | "paused" | "gameover", snapshot?: SimulationSnapshot): void {
    if (!this.stateNode) {
      return;
    }
    if (!snapshot) {
      this.stateNode.textContent = `phase=${phase} muted=${this.preferences.muted}`;
      return;
    }
    this.stateNode.textContent = `phase=${phase} score=${snapshot.score} wave=${snapshot.wave} health=${snapshot.player.health} tick=${snapshot.tick} muted=${this.preferences.muted}`;
  }

  private setMenuVisible(visible: boolean): void {
    for (const object of this.menuObjects) {
      this.setObjectVisibility(object, visible);
    }
  }

  private setHudVisible(visible: boolean): void {
    for (const object of this.hudObjects) {
      this.setObjectVisibility(object, visible);
    }
    this.arenaBorder?.setVisible(visible);
    this.arenaBackground?.setVisible(visible);
    this.enemyHealthBars?.setVisible(visible);
    this.crosshair?.setVisible(visible);
    this.hitFlash?.setVisible(visible);
    this.playerSprite?.setVisible(visible);
    for (const sprite of this.enemySprites.values()) {
      sprite.setVisible(visible);
    }
    for (const sprite of this.projectileSprites.values()) {
      sprite.setVisible(visible);
    }
  }

  private setPauseVisible(visible: boolean): void {
    for (const object of this.pauseObjects) {
      this.setObjectVisibility(object, visible);
    }
  }

  private setGameOverVisible(visible: boolean): void {
    for (const object of this.gameOverObjects) {
      this.setObjectVisibility(object, visible);
    }
  }

  private setObjectVisibility(object: Phaser.GameObjects.GameObject, visible: boolean): void {
    const displayObject = object as unknown as { visible: boolean; active: boolean };
    displayObject.visible = visible;
    displayObject.active = visible;
  }
}

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  backgroundColor: COLORS.background,
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
  scene: ArenaScene,
});

export { ArenaScene, game };
