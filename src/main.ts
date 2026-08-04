import Phaser from "phaser";
import {
  FIXED_TIMESTEP_MS,
  Simulation,
  type SimulationEvent,
} from "./game/simulation";
import "./styles.css";

const GAME_WIDTH = 1280;
const GAME_HEIGHT = 720;
const ASSET_ROOT = `${import.meta.env.BASE_URL}benchmark-assets/vector-siege`;
const DEFAULT_SEED = 0x5eed2026;
const STORAGE_KEYS = {
  highScore: "vector-siege.high-score",
  volume: "vector-siege.volume",
  muted: "vector-siege.muted",
};

type ScreenPhase = "menu" | "running" | "paused" | "gameover";

type RenderState = {
  seed: number;
  tick: number;
  status: string;
  score: number;
  wave: number;
  player: {
    x: number;
    y: number;
    health: number;
    maxHealth: number;
    invulnerableUntilTick?: number;
    invulnerabilityUntilTick?: number;
    invulnerabilityTicks?: number;
  };
  enemies: Array<{
    id: number;
    x: number;
    y: number;
    kind?: string;
    type?: string;
    variant?: string;
    health?: number;
    maxHealth?: number;
    radius?: number;
  }>;
  projectiles: Array<{
    id: number;
    x: number;
    y: number;
  }>;
  completedRecord?: {
    seed: number;
    finalTick: number;
  };
};

type EventLike = SimulationEvent & {
  enemyId?: number;
  enemyKind?: string;
  x?: number;
  y?: number;
  score?: number;
};

type Preferences = {
  highScore: number;
  volume: number;
  muted: boolean;
};

const asset = (path: string) => `${ASSET_ROOT}/${path}`;

function readPreferences(): Preferences {
  const safeRead = (key: string) => {
    try {
      return window.localStorage.getItem(key);
    } catch {
      return null;
    }
  };

  const storedVolume = Number(safeRead(STORAGE_KEYS.volume));
  const storedHighScore = Number(safeRead(STORAGE_KEYS.highScore));
  return {
    highScore: Number.isFinite(storedHighScore) ? Math.max(0, storedHighScore) : 0,
    volume: Number.isFinite(storedVolume) ? Phaser.Math.Clamp(storedVolume, 0, 1) : 0.65,
    muted: safeRead(STORAGE_KEYS.muted) === "true",
  };
}

function writePreference(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Storage is an enhancement; a blocked storage partition must not stop play.
  }
}

class VectorSiegeScene extends Phaser.Scene {
  private phase: ScreenPhase = "menu";
  private simulation?: Simulation;
  private accumulator = 0;
  private runSeed = DEFAULT_SEED;
  private pointerX = GAME_WIDTH / 2;
  private pointerY = GAME_HEIGHT / 2;
  private pointerHeld = false;
  private fireRequest = false;
  private keys!: Record<string, any>;
  private cursors!: any;
  private spaceKey!: any;
  private pauseKey!: any;
  private muteKey!: any;

  private menuBackground!: Phaser.GameObjects.Image;
  private arenaBackground!: Phaser.GameObjects.Image;
  private playerSprite?: Phaser.GameObjects.Image;
  private enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private projectileSprites = new Map<number, Phaser.GameObjects.Arc>();
  private effectSprites = new Set<Phaser.GameObjects.Sprite>();
  private crosshair!: Phaser.GameObjects.Graphics;
  private arenaFrame!: Phaser.GameObjects.Graphics;
  private menuPanel!: Phaser.GameObjects.Graphics;
  private pausePanel!: Phaser.GameObjects.Graphics;
  private gameOverPanel!: Phaser.GameObjects.Graphics;
  private playerHitFlash!: Phaser.GameObjects.Graphics;

  private logo!: Phaser.GameObjects.Image;
  private menuKicker!: Phaser.GameObjects.Text;
  private menuBody!: Phaser.GameObjects.Text;
  private menuHighScore!: Phaser.GameObjects.Text;
  private hudGroup!: Phaser.GameObjects.Group;
  private scoreText!: Phaser.GameObjects.Text;
  private healthText!: Phaser.GameObjects.Text;
  private waveText!: Phaser.GameObjects.Text;
  private highScoreText!: Phaser.GameObjects.Text;
  private seedText!: Phaser.GameObjects.Text;
  private pauseTitle!: Phaser.GameObjects.Text;
  private pauseCopy!: Phaser.GameObjects.Text;
  private gameOverTitle!: Phaser.GameObjects.Text;
  private gameOverBody!: Phaser.GameObjects.Text;
  private gameOverRecord!: Phaser.GameObjects.Text;
  private objectiveText!: Phaser.GameObjects.Text;
  private music?: any;
  private preferences = readPreferences();

  private startButton!: HTMLButtonElement;
  private pauseButton!: HTMLButtonElement;
  private muteButton!: HTMLButtonElement;
  private restartButton!: HTMLButtonElement;
  private menuActions!: HTMLElement;
  private runControls!: HTMLElement;
  private gameOverActions!: HTMLElement;
  private volumeSlider!: HTMLInputElement;
  private screenReaderStatus!: HTMLElement;

  constructor() {
    super("VectorSiege");
  }

  preload(): void {
    this.load.image("menu-background", asset("visuals/menu-background.webp"));
    this.load.image("arena-background", asset("visuals/arena-background.webp"));
    this.load.image("logo", asset("visuals/logo.webp"));
    this.load.image("player", asset("visuals/player.webp"));
    this.load.image("enemy-chaser", asset("visuals/enemies/chaser.webp"));
    this.load.image("enemy-striker", asset("visuals/enemies/striker.webp"));
    this.load.image("enemy-tank", asset("visuals/enemies/tank.webp"));
    this.load.image("ui-heart", asset("visuals/ui/heart.webp"));
    this.load.image("ui-score", asset("visuals/ui/score.webp"));
    this.load.image("ui-wave", asset("visuals/ui/wave.webp"));
    this.load.atlas(
      "impact",
      asset("visuals/effects/impact-atlas.webp"),
      asset("visuals/effects/impact-atlas.json"),
    );
    this.load.atlas(
      "explosion",
      asset("visuals/effects/explosion-atlas.webp"),
      asset("visuals/effects/explosion-atlas.json"),
    );

    this.load.audio("menu-theme", asset("audio/menu-theme.mp3"));
    this.load.audio("gameplay-loop", asset("audio/gameplay-loop.mp3"));
    this.load.audio("shoot", asset("audio/shoot.wav"));
    this.load.audio("enemy-hit", asset("audio/enemy-hit.wav"));
    this.load.audio("enemy-defeat", asset("audio/enemy-defeat.wav"));
    this.load.audio("player-hit", asset("audio/player-hit.wav"));
    this.load.audio("wave-start", asset("audio/wave-start.wav"));
    this.load.audio("game-over", asset("audio/game-over.wav"));
  }

  create(): void {
    this.cameras.main.setBackgroundColor(0x08111f);
    this.createAnimations();
    this.createWorldObjects();
    this.setupInput();
    this.setupDomControls();
    this.applyAudioPreferences();
    this.showMenu();

    this.game.events.on("blur", this.handleWindowBlur, this);
    this.events.once("shutdown", () => {
      this.game.events.off("blur", this.handleWindowBlur, this);
      this.music?.stop();
    });
  }

  update(_time: number, delta: number): void {
    if (this.pauseKey && Phaser.Input.Keyboard.JustDown(this.pauseKey)) {
      this.togglePause();
    }
    if (this.muteKey && Phaser.Input.Keyboard.JustDown(this.muteKey)) {
      this.toggleMute();
    }
    if (this.phase !== "running" || !this.simulation) {
      this.updateCrosshair();
      return;
    }

    this.accumulator += Math.min(delta, 100);
    while (this.accumulator >= FIXED_TIMESTEP_MS) {
      this.accumulator -= FIXED_TIMESTEP_MS;
      const events = this.simulation.step(this.readSimulationInput());
      this.processSimulationEvents(events);
      if (this.phase !== "running") {
        this.accumulator = 0;
        break;
      }
    }

    this.renderSimulation();
  }

  private createAnimations(): void {
    this.anims.create({
      key: "impact-burst",
      frames: this.anims.generateFrameNames("impact", {
        prefix: "frame-",
        start: 0,
        end: 3,
      }),
      frameRate: 24,
      repeat: 0,
    });
    this.anims.create({
      key: "explosion-burst",
      frames: this.anims.generateFrameNames("explosion", {
        prefix: "frame-",
        start: 0,
        end: 3,
      }),
      frameRate: 18,
      repeat: 0,
    });
  }

  private createWorldObjects(): void {
    this.menuBackground = this.add
      .image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "menu-background")
      .setDisplaySize(GAME_WIDTH, GAME_HEIGHT)
      .setDepth(-10);
    this.arenaBackground = this.add
      .image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "arena-background")
      .setDisplaySize(GAME_WIDTH, GAME_HEIGHT)
      .setDepth(-10)
      .setVisible(false);

    this.arenaFrame = this.add.graphics().setDepth(1);
    this.arenaFrame.lineStyle(2, 0x49dcb1, 0.22);
    this.arenaFrame.strokeRoundedRect(28, 28, GAME_WIDTH - 56, GAME_HEIGHT - 56, 14);
    this.arenaFrame.lineStyle(1, 0x61728b, 0.18);
    this.arenaFrame.strokeRoundedRect(42, 42, GAME_WIDTH - 84, GAME_HEIGHT - 84, 8);

    this.crosshair = this.add.graphics().setDepth(12);
    this.playerHitFlash = this.add.graphics().setDepth(11).setVisible(false);

    this.menuPanel = this.add.graphics().setDepth(3);
    this.menuPanel.fillStyle(0x06121d, 0.84);
    this.menuPanel.fillRoundedRect(310, 94, 660, 532, 18);
    this.menuPanel.lineStyle(1, 0x49dcb1, 0.32);
    this.menuPanel.strokeRoundedRect(310, 94, 660, 532, 18);
    this.menuPanel.lineStyle(1, 0xf6c453, 0.18);
    this.menuPanel.strokeRoundedRect(326, 110, 628, 500, 12);

    this.logo = this.add
      .image(GAME_WIDTH / 2, 187, "logo")
      .setDisplaySize(390, 195)
      .setDepth(4);
    this.menuKicker = this.add
      .text(GAME_WIDTH / 2, 286, "VECTOR SIEGE  //  ARENA PROTOCOL 01", this.textStyle(14, "#49dcb1"))
      .setOrigin(0.5)
      .setDepth(4);
    this.menuBody = this.add
      .text(
        GAME_WIDTH / 2,
        344,
        "SURVIVE THE SIGNAL STORM\n\nWASD / ARROWS   MOVE\nPOINTER   AIM     CLICK / SPACE   FIRE\nP   PAUSE        M   MUTE",
        this.textStyle(16, "#d9eaf2", true),
      )
      .setOrigin(0.5)
      .setAlign("center")
      .setDepth(4);
    this.menuHighScore = this.add
      .text(GAME_WIDTH / 2, 548, "HIGH SCORE  000000", this.textStyle(13, "#f6c453"))
      .setOrigin(0.5)
      .setDepth(4);

    this.pausePanel = this.add.graphics().setDepth(20).setVisible(false);
    this.pausePanel.fillStyle(0x06121d, 0.9);
    this.pausePanel.fillRoundedRect(400, 245, 480, 230, 16);
    this.pausePanel.lineStyle(2, 0xf6c453, 0.7);
    this.pausePanel.strokeRoundedRect(400, 245, 480, 230, 16);
    this.pauseTitle = this.add
      .text(GAME_WIDTH / 2, 316, "SYSTEM PAUSED", this.textStyle(28, "#f6c453"))
      .setOrigin(0.5)
      .setDepth(21)
      .setVisible(false);
    this.pauseCopy = this.add
      .text(GAME_WIDTH / 2, 382, "PRESS P OR RESUME TO RETURN\nTHE ARENA IS HOLDING POSITION", this.textStyle(14, "#d9eaf2", true))
      .setOrigin(0.5)
      .setAlign("center")
      .setDepth(21)
      .setVisible(false)
      .setName("pause-copy");

    this.gameOverPanel = this.add.graphics().setDepth(20).setVisible(false);
    this.gameOverPanel.fillStyle(0x120b18, 0.92);
    this.gameOverPanel.fillRoundedRect(350, 188, 580, 360, 16);
    this.gameOverPanel.lineStyle(2, 0xff4f78, 0.72);
    this.gameOverPanel.strokeRoundedRect(350, 188, 580, 360, 16);
    this.gameOverPanel.lineStyle(1, 0xf6c453, 0.22);
    this.gameOverPanel.strokeRoundedRect(366, 204, 548, 328, 12);
    this.gameOverTitle = this.add
      .text(GAME_WIDTH / 2, 260, "SIGNAL LOST", this.textStyle(36, "#ff4f78"))
      .setOrigin(0.5)
      .setDepth(21)
      .setVisible(false);
    this.gameOverBody = this.add
      .text(GAME_WIDTH / 2, 348, "RUN TERMINATED", this.textStyle(18, "#d9eaf2", true))
      .setOrigin(0.5)
      .setDepth(21)
      .setVisible(false);
    this.gameOverRecord = this.add
      .text(GAME_WIDTH / 2, 418, "SCORE  000000   //   WAVE  01", this.textStyle(16, "#f6c453"))
      .setOrigin(0.5)
      .setDepth(21)
      .setVisible(false);

    this.hudGroup = this.add.group({ runChildUpdate: false });
    const hudPanel = this.add.graphics().setDepth(8);
    hudPanel.fillStyle(0x06121d, 0.78);
    hudPanel.fillRoundedRect(28, 26, 432, 72, 10);
    hudPanel.lineStyle(1, 0x49dcb1, 0.28);
    hudPanel.strokeRoundedRect(28, 26, 432, 72, 10);
    this.hudGroup.add(hudPanel);

    const heart = this.add.image(64, 62, "ui-heart").setDisplaySize(26, 26).setDepth(9);
    const scoreIcon = this.add.image(198, 62, "ui-score").setDisplaySize(26, 26).setDepth(9);
    const waveIcon = this.add.image(332, 62, "ui-wave").setDisplaySize(26, 26).setDepth(9);
    this.hudGroup.addMultiple([heart, scoreIcon, waveIcon]);
    this.healthText = this.add.text(84, 50, "HP  03 / 03", this.textStyle(15, "#ff4f78", true)).setDepth(9);
    this.scoreText = this.add.text(218, 50, "000000", this.textStyle(18, "#f6c453", true)).setDepth(9);
    this.waveText = this.add.text(352, 50, "WAVE 01", this.textStyle(15, "#49dcb1", true)).setDepth(9);
    this.highScoreText = this.add.text(48, 116, "BEST 000000", this.textStyle(11, "#d9eaf2")).setDepth(9);
    this.seedText = this.add.text(1190, 114, "SEED --------", this.textStyle(11, "#61728b")).setOrigin(1, 0).setDepth(9);
    this.objectiveText = this.add
      .text(640, 688, "CLEAR THE WAVE  //  POINTER AIM ACTIVE", this.textStyle(11, "#d9eaf2"))
      .setOrigin(0.5, 1)
      .setDepth(9);
    this.hudGroup.addMultiple([this.healthText, this.scoreText, this.waveText, this.highScoreText, this.seedText, this.objectiveText]);
    this.hudGroup.setVisible(false);
  }

  private setupInput(): void {
    const keyboard = this.input.keyboard!;
    this.cursors = keyboard.createCursorKeys();
    this.keys = keyboard.addKeys("W,A,S,D,P,M") as Record<string, any>;
    this.spaceKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);
    this.pauseKey = this.keys.P;
    this.muteKey = this.keys.M;
    keyboard.addCapture("W,A,S,D,SPACE,UP,DOWN,LEFT,RIGHT,P,M");

    this.input.on("pointermove", (pointer: any) => {
      this.pointerX = Phaser.Math.Clamp(pointer.worldX ?? pointer.x, 0, GAME_WIDTH);
      this.pointerY = Phaser.Math.Clamp(pointer.worldY ?? pointer.y, 0, GAME_HEIGHT);
    });
    this.input.on("pointerdown", (pointer: any) => {
      this.pointerX = Phaser.Math.Clamp(pointer.worldX ?? pointer.x, 0, GAME_WIDTH);
      this.pointerY = Phaser.Math.Clamp(pointer.worldY ?? pointer.y, 0, GAME_HEIGHT);
      if (this.phase === "running") {
        this.pointerHeld = true;
        this.fireRequest = true;
      }
    });
    this.input.on("pointerup", () => {
      this.pointerHeld = false;
    });
  }

  private setupDomControls(): void {
    const get = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
    this.startButton = get<HTMLButtonElement>("start-button");
    this.pauseButton = get<HTMLButtonElement>("pause-button");
    this.muteButton = get<HTMLButtonElement>("mute-button");
    this.restartButton = get<HTMLButtonElement>("restart-button");
    this.menuActions = get<HTMLElement>("menu-actions");
    this.runControls = get<HTMLElement>("run-controls");
    this.gameOverActions = get<HTMLElement>("game-over-actions");
    this.volumeSlider = get<HTMLInputElement>("volume-slider");
    this.screenReaderStatus = get<HTMLElement>("screen-reader-status");

    this.startButton.addEventListener("click", () => this.startRun());
    this.restartButton.addEventListener("click", () => this.startRun());
    this.pauseButton.addEventListener("click", () => this.togglePause());
    this.muteButton.addEventListener("click", () => this.toggleMute());
    this.volumeSlider.value = String(Math.round(this.preferences.volume * 100));
    this.volumeSlider.addEventListener("input", () => {
      this.preferences.volume = Phaser.Math.Clamp(Number(this.volumeSlider.value) / 100, 0, 1);
      writePreference(STORAGE_KEYS.volume, String(this.preferences.volume));
      this.applyAudioPreferences();
    });
    this.updateMuteButton();
  }

  private applyAudioPreferences(): void {
    this.sound.setVolume(this.preferences.volume);
    this.sound.setMute(this.preferences.muted);
    this.music?.setVolume(0.6);
    this.updateMuteButton();
  }

  private updateMuteButton(): void {
    if (!this.muteButton) {
      return;
    }
    this.muteButton.textContent = this.preferences.muted ? "SOUND: OFF" : "SOUND: ON";
    this.muteButton.setAttribute("aria-pressed", String(this.preferences.muted));
  }

  private toggleMute(): void {
    this.preferences.muted = !this.preferences.muted;
    writePreference(STORAGE_KEYS.muted, String(this.preferences.muted));
    this.applyAudioPreferences();
    this.announce(this.preferences.muted ? "Sound muted" : "Sound restored");
  }

  private showMenu(): void {
    this.phase = "menu";
    this.menuBackground.setVisible(true);
    this.arenaBackground.setVisible(false);
    this.menuPanel.setVisible(true);
    this.logo.setVisible(true);
    this.menuKicker.setVisible(true);
    this.menuBody.setVisible(true);
    this.menuHighScore.setText(`HIGH SCORE  ${this.pad(this.preferences.highScore)}`).setVisible(true);
    this.hudGroup.setVisible(false);
    this.pausePanel.setVisible(false);
    this.pauseTitle.setVisible(false);
    this.pauseCopy.setVisible(false);
    this.gameOverPanel.setVisible(false);
    this.gameOverTitle.setVisible(false);
    this.gameOverBody.setVisible(false);
    this.gameOverRecord.setVisible(false);
    this.menuActions.hidden = false;
    this.runControls.hidden = true;
    this.gameOverActions.hidden = true;
    this.playMusic("menu-theme");
    this.announce("Vector Siege ready. Start run to deploy.");
  }

  private startRun(): void {
    this.runSeed = this.readSeed();
    this.clearRunObjects();
    this.simulation = new Simulation({
      seed: this.runSeed,
      width: GAME_WIDTH,
      height: GAME_HEIGHT,
      spawnRadius: 260,
    });
    this.phase = "running";
    this.accumulator = 0;
    this.fireRequest = false;
    this.pointerHeld = false;
    this.menuBackground.setVisible(false);
    this.arenaBackground.setVisible(true);
    this.menuPanel.setVisible(false);
    this.logo.setVisible(false);
    this.menuKicker.setVisible(false);
    this.menuBody.setVisible(false);
    this.menuHighScore.setVisible(false);
    this.pausePanel.setVisible(false);
    this.pauseTitle.setVisible(false);
    this.pauseCopy.setVisible(false);
    this.gameOverPanel.setVisible(false);
    this.gameOverTitle.setVisible(false);
    this.gameOverBody.setVisible(false);
    this.gameOverRecord.setVisible(false);
    this.hudGroup.setVisible(true);
    this.menuActions.hidden = true;
    this.runControls.hidden = false;
    this.gameOverActions.hidden = true;
    this.pauseButton.textContent = "PAUSE";
    this.playerSprite = this.add.image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "player").setDisplaySize(66, 66).setDepth(5);
    this.playMusic("gameplay-loop");
    this.playSfx("wave-start", 0.72);
    this.announce("Run started");
    this.renderSimulation();
  }

  private togglePause(): void {
    if (this.phase === "running") {
      this.phase = "paused";
      this.pausePanel.setVisible(true);
      this.pauseTitle.setVisible(true);
      this.pauseCopy.setVisible(true);
      this.pauseTitle.setText("SYSTEM PAUSED");
      this.pauseButton.textContent = "RESUME";
      this.music?.pause();
      this.announce("Run paused");
    } else if (this.phase === "paused") {
      this.phase = "running";
      this.pausePanel.setVisible(false);
      this.pauseTitle.setVisible(false);
      this.pauseCopy.setVisible(false);
      this.pauseButton.textContent = "PAUSE";
      this.music?.resume();
      this.announce("Run resumed");
    }
  }

  private handleWindowBlur(): void {
    if (this.phase === "running") {
      this.togglePause();
    }
  }

  private readSeed(): number {
    const querySeed = new URLSearchParams(window.location.search).get("seed");
    const parsed = querySeed === null ? DEFAULT_SEED : Number(querySeed);
    return Number.isFinite(parsed) ? parsed >>> 0 : DEFAULT_SEED;
  }

  private readSimulationInput(): {
    moveX: number;
    moveY: number;
    aimX: number;
    aimY: number;
    fire: boolean;
    firePressed: boolean;
  } {
    let moveX = 0;
    let moveY = 0;
    if (this.keys.A?.isDown || this.cursors.left.isDown) moveX -= 1;
    if (this.keys.D?.isDown || this.cursors.right.isDown) moveX += 1;
    if (this.keys.W?.isDown || this.cursors.up.isDown) moveY -= 1;
    if (this.keys.S?.isDown || this.cursors.down.isDown) moveY += 1;
    const firePressed = this.fireRequest || Phaser.Input.Keyboard.JustDown(this.spaceKey);
    this.fireRequest = false;
    return {
      moveX,
      moveY,
      aimX: this.pointerX,
      aimY: this.pointerY,
      fire: this.pointerHeld || this.spaceKey.isDown || firePressed,
      firePressed,
    };
  }

  private processSimulationEvents(events: SimulationEvent[]): void {
    for (const rawEvent of events) {
      const event = rawEvent as EventLike;
      switch (event.type) {
        case "shot":
          this.playSfx("shoot", 0.72);
          break;
        case "enemy-hit":
          this.playSfx("enemy-hit", 0.62);
          this.spawnEffect("impact-burst", event.x ?? this.pointerX, event.y ?? this.pointerY, 0.78);
          break;
        case "enemy-defeated":
          this.playSfx("enemy-defeat", 0.78);
          this.spawnEffect("explosion-burst", event.x ?? this.pointerX, event.y ?? this.pointerY, 1.15);
          break;
        case "player-hit":
          this.playSfx("player-hit", 0.82);
          this.flashPlayerHit();
          break;
        case "wave-start":
          this.playSfx("wave-start", 0.72);
          break;
        case "game-over":
          this.finishRun();
          break;
      }
    }
  }

  private finishRun(): void {
    if (this.phase === "gameover") {
      return;
    }
    this.phase = "gameover";
    this.pausePanel.setVisible(false);
    this.pauseTitle.setVisible(false);
    this.pauseCopy.setVisible(false);
    this.gameOverPanel.setVisible(true);
    this.gameOverTitle.setVisible(true);
    this.gameOverBody.setVisible(true);
    this.gameOverRecord.setVisible(true);
    this.pauseButton.textContent = "PAUSE";
    this.menuActions.hidden = true;
    this.runControls.hidden = false;
    this.gameOverActions.hidden = false;
    const state = this.currentState();
    const score = state?.score ?? 0;
    const wave = state?.wave ?? 1;
    const finalTick = state?.completedRecord?.finalTick ?? state?.tick ?? 0;
    const completedSeed = state?.completedRecord?.seed ?? this.runSeed;
    if (score > this.preferences.highScore) {
      this.preferences.highScore = score;
      writePreference(STORAGE_KEYS.highScore, String(score));
    }
    this.gameOverRecord.setText(`SCORE  ${this.pad(score)}   //   WAVE  ${String(wave).padStart(2, "0")}`);
    this.highScoreText.setText(`BEST ${this.pad(this.preferences.highScore)}`);
    this.seedText.setText(`SEED ${completedSeed.toString(16).padStart(8, "0").toUpperCase()}`);
    this.playSfx("game-over", 0.88);
    this.music?.stop();
    this.announce(`Run complete. Score ${score}. Final tick ${finalTick}.`);
    this.renderSimulation();
  }

  private currentState(): RenderState | undefined {
    return this.simulation?.state as unknown as RenderState | undefined;
  }

  private renderSimulation(): void {
    const state = this.currentState();
    if (!state || !this.playerSprite) {
      this.updateCrosshair();
      return;
    }

    this.playerSprite.setPosition(state.player.x, state.player.y);
    this.playerSprite.setRotation(Math.atan2(this.pointerY - state.player.y, this.pointerX - state.player.x) + Math.PI / 2);
    const invulnerableUntil = state.player.invulnerableUntilTick ?? state.player.invulnerabilityUntilTick ?? 0;
    const invulnerable = invulnerableUntil > state.tick || (state.player.invulnerabilityTicks ?? 0) > 0;
    this.playerSprite.setAlpha(invulnerable ? 0.5 + Math.abs(Math.sin(state.tick * 0.35)) * 0.4 : 1);

    const liveEnemyIds = new Set<number>();
    for (const enemy of state.enemies) {
      liveEnemyIds.add(enemy.id);
      const kind = (enemy.kind ?? enemy.variant ?? enemy.type ?? "chaser").toLowerCase();
      const texture = kind.includes("tank") ? "enemy-tank" : kind.includes("strik") ? "enemy-striker" : "enemy-chaser";
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.add.image(enemy.x, enemy.y, texture).setDepth(4);
        this.enemySprites.set(enemy.id, sprite);
      } else if (sprite.texture.key !== texture) {
        sprite.setTexture(texture);
      }
      const displaySize = Phaser.Math.Clamp((enemy.radius ?? 24) * 2.1, 42, 72);
      sprite.setDisplaySize(displaySize, displaySize);
      sprite.setPosition(enemy.x, enemy.y);
      sprite.setRotation(Math.atan2(state.player.y - enemy.y, state.player.x - enemy.x));
      const damageFlash = enemy.health !== undefined && enemy.maxHealth !== undefined && enemy.health < enemy.maxHealth;
      sprite.setAlpha(damageFlash ? 0.82 : 1);
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!liveEnemyIds.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
      }
    }

    const liveProjectileIds = new Set<number>();
    for (const projectile of state.projectiles) {
      liveProjectileIds.add(projectile.id);
      let sprite = this.projectileSprites.get(projectile.id);
      if (!sprite) {
        sprite = this.add.circle(projectile.x, projectile.y, 5, 0x49dcb1, 1).setDepth(6);
        sprite.setStrokeStyle(2, 0xc9fff1, 0.85);
        this.projectileSprites.set(projectile.id, sprite);
      }
      sprite.setPosition(projectile.x, projectile.y);
    }
    for (const [id, sprite] of this.projectileSprites) {
      if (!liveProjectileIds.has(id)) {
        sprite.destroy();
        this.projectileSprites.delete(id);
      }
    }

    this.scoreText.setText(this.pad(state.score));
    this.healthText.setText(`HP  ${String(state.player.health).padStart(2, "0")} / ${String(state.player.maxHealth).padStart(2, "0")}`);
    this.waveText.setText(`WAVE ${String(state.wave).padStart(2, "0")}`);
    this.highScoreText.setText(`BEST ${this.pad(Math.max(this.preferences.highScore, state.score))}`);
    this.seedText.setText(`SEED ${state.seed.toString(16).padStart(8, "0").toUpperCase()}`);
    this.objectiveText.setText(state.enemies.length ? "CLEAR THE WAVE  //  POINTER AIM ACTIVE" : "WAVE CLEAR  //  NEXT SIGNAL INBOUND");
    const shell = document.getElementById("game-shell");
    shell?.setAttribute("data-score", String(state.score));
    shell?.setAttribute("data-wave", String(state.wave));
    shell?.setAttribute("data-tick", String(state.tick));
    shell?.setAttribute("data-status", state.status);
    this.updateCrosshair();
  }

  private updateCrosshair(): void {
    this.crosshair.clear();
    if (this.phase === "menu") {
      return;
    }
    this.crosshair.lineStyle(1, 0x49dcb1, 0.78);
    this.crosshair.strokeCircle(this.pointerX, this.pointerY, 12);
    this.crosshair.lineBetween(this.pointerX - 19, this.pointerY, this.pointerX - 7, this.pointerY);
    this.crosshair.lineBetween(this.pointerX + 7, this.pointerY, this.pointerX + 19, this.pointerY);
    this.crosshair.lineBetween(this.pointerX, this.pointerY - 19, this.pointerX, this.pointerY - 7);
    this.crosshair.lineBetween(this.pointerX, this.pointerY + 7, this.pointerX, this.pointerY + 19);
    this.crosshair.fillStyle(0xf6c453, 0.9);
    this.crosshair.fillCircle(this.pointerX, this.pointerY, 2);
  }

  private spawnEffect(animation: string, x: number, y: number, scale: number): void {
    const effect = this.add.sprite(x, y, animation.startsWith("explosion") ? "explosion" : "impact", "frame-0");
    effect.setDepth(7).setScale(scale);
    effect.play(animation);
    this.effectSprites.add(effect);
    effect.once("animationcomplete", () => {
      this.effectSprites.delete(effect);
      effect.destroy();
    });
  }

  private flashPlayerHit(): void {
    this.playerHitFlash.clear();
    this.playerHitFlash.fillStyle(0xff4f78, 0.15);
    this.playerHitFlash.fillRect(0, 0, GAME_WIDTH, GAME_HEIGHT);
    this.playerHitFlash.setVisible(true);
    this.time.delayedCall(120, () => this.playerHitFlash.setVisible(false));
  }

  private playMusic(key: string): void {
    this.music?.stop();
    this.music = this.sound.add(key, { loop: true, volume: 0.6 });
    this.music.play();
    this.applyAudioPreferences();
  }

  private playSfx(key: string, volume: number): void {
    if (this.preferences.muted || this.preferences.volume <= 0) {
      return;
    }
    try {
      this.sound.play(key, { volume });
    } catch {
      // A locked or unsupported audio backend should never interrupt simulation.
    }
  }

  private clearRunObjects(): void {
    this.playerSprite?.destroy();
    this.playerSprite = undefined;
    for (const sprite of this.enemySprites.values()) sprite.destroy();
    for (const sprite of this.projectileSprites.values()) sprite.destroy();
    for (const sprite of this.effectSprites) sprite.destroy();
    this.enemySprites.clear();
    this.projectileSprites.clear();
    this.effectSprites.clear();
  }

  private textStyle(size: number, color: string, bold = false): Phaser.Types.GameObjects.Text.TextStyle {
    return {
      fontFamily: "Trebuchet MS, Segoe UI, sans-serif",
      fontSize: `${size}px`,
      fontStyle: bold ? "bold" : "normal",
      color,
      stroke: "#06121d",
      strokeThickness: 3,
      letterSpacing: size <= 14 ? 1.2 : 0.4,
    };
  }

  private pad(value: number): string {
    return Math.max(0, Math.round(value)).toString().padStart(6, "0");
  }

  private announce(message: string): void {
    if (this.screenReaderStatus) {
      this.screenReaderStatus.textContent = message;
    }
    document.getElementById("game-shell")?.setAttribute("data-phase", this.phase);
  }
}

new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  backgroundColor: "#08111f",
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
  },
  input: {
    keyboard: true,
    mouse: true,
    touch: true,
    activePointers: 1,
  },
  fps: {
    target: 60,
    smoothStep: false,
  },
  render: {
    antialias: true,
    roundPixels: true,
  },
  scene: VectorSiegeScene,
});
