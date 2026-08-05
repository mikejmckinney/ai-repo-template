import Phaser from "phaser";
import {
  VectorSiegeSimulation,
  type EnemyState,
  type Point,
  type SimulationEvent,
  type SimulationInput,
  type SimulationState,
} from "./shared-simulation";

const WIDTH = 1280;
const HEIGHT = 720;
const ASSET_ROOT = "/benchmark-assets/vector-siege";
const SETTINGS_KEY = "vector-siege:settings";
const DEFAULT_SEED = 1337;

const COLORS = {
  background: 0x08111f,
  accent: 0x49dcb1,
  danger: 0xff4f78,
  highlight: 0xf6c453,
  muted: 0x61728b,
} as const;

interface AudioSettings {
  version: 1;
  highScore: number;
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
}

const clamp = (value: number, minimum: number, maximum: number): number =>
  Math.min(maximum, Math.max(minimum, value));

const element = <T extends HTMLElement>(id: string): T => {
  const node = document.getElementById(id);
  if (!node) throw new Error(`Vector Siege UI element is missing: #${id}`);
  return node as T;
};

const defaultSettings = (): AudioSettings => ({
  version: 1,
  highScore: 0,
  musicVolume: 0.28,
  effectsVolume: 0.45,
  muted: false,
});

const readSettings = (): AudioSettings => {
  const fallback = defaultSettings();
  try {
    const raw = window.localStorage.getItem(SETTINGS_KEY);
    if (!raw) return fallback;
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return fallback;
    const value = parsed as Partial<AudioSettings>;
    return {
      version: 1,
      highScore: Number.isFinite(value.highScore) ? Math.max(0, Math.floor(value.highScore as number)) : fallback.highScore,
      musicVolume: Number.isFinite(value.musicVolume) ? clamp(value.musicVolume as number, 0, 1) : fallback.musicVolume,
      effectsVolume: Number.isFinite(value.effectsVolume) ? clamp(value.effectsVolume as number, 0, 1) : fallback.effectsVolume,
      muted: Boolean(value.muted),
    };
  } catch (error) {
    console.warn("Vector Siege could not read saved audio settings; using defaults.", error);
    return fallback;
  }
};

const writeSettings = (settings: AudioSettings): void => {
  try {
    window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch (error) {
    console.warn("Vector Siege could not persist local settings.", error);
  }
};

const seedFromLocation = (): number => {
  const requested = Number(new URLSearchParams(window.location.search).get("seed"));
  return Number.isFinite(requested) ? Math.trunc(requested) : DEFAULT_SEED;
};

class ArenaScene extends Phaser.Scene {
  private simulation!: VectorSiegeSimulation;
  private simulationState!: SimulationState;
  private settings = readSettings();
  private menuBackground!: Phaser.GameObjects.Image;
  private arenaBackground!: Phaser.GameObjects.Image;
  private logo!: Phaser.GameObjects.Image;
  private playerSprite!: Phaser.GameObjects.Image;
  private aimGraphic!: Phaser.GameObjects.Graphics;
  private enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private enemyHealthBars = new Map<number, Phaser.GameObjects.Rectangle>();
  private projectileSprites = new Map<number, Phaser.GameObjects.Arc>();
  private keys!: Record<"w" | "a" | "s" | "d" | "up" | "left" | "down" | "right" | "space" | "pause", Phaser.Input.Keyboard.Key>;
  private pointer: Point = { x: WIDTH / 2, y: HEIGHT / 2 };
  private pointerDown = false;
  private runStarted = false;
  private audioUnlocked = false;
  private gameplayMusic?: Phaser.Sound.BaseSound;
  private menuMusic?: Phaser.Sound.BaseSound;
  private lastEnemyPositions = new Map<number, Point>();

  public constructor() {
    super("ArenaScene");
  }

  public preload(): void {
    this.load.image("menu-background", `${ASSET_ROOT}/visuals/menu-background.webp`);
    this.load.image("arena-background", `${ASSET_ROOT}/visuals/arena-background.webp`);
    this.load.image("logo", `${ASSET_ROOT}/visuals/logo.webp`);
    this.load.image("player", `${ASSET_ROOT}/visuals/player.webp`);
    this.load.image("enemy-chaser", `${ASSET_ROOT}/visuals/enemies/chaser.webp`);
    this.load.image("enemy-striker", `${ASSET_ROOT}/visuals/enemies/striker.webp`);
    this.load.image("enemy-tank", `${ASSET_ROOT}/visuals/enemies/tank.webp`);
    this.load.image("ui-heart", `${ASSET_ROOT}/visuals/ui/heart.webp`);
    this.load.image("ui-score", `${ASSET_ROOT}/visuals/ui/score.webp`);
    this.load.image("ui-wave", `${ASSET_ROOT}/visuals/ui/wave.webp`);
    this.load.atlas(
      "explosion-atlas",
      `${ASSET_ROOT}/visuals/effects/explosion-atlas.webp`,
      `${ASSET_ROOT}/visuals/effects/explosion-atlas.json`,
    );
    this.load.atlas(
      "impact-atlas",
      `${ASSET_ROOT}/visuals/effects/impact-atlas.webp`,
      `${ASSET_ROOT}/visuals/effects/impact-atlas.json`,
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
    const canvas = this.game.canvas;
    canvas.dataset.testid = "game-canvas";
    canvas.setAttribute("aria-label", "Vector Siege arena canvas");

    this.createBackgrounds();
    this.createAnimations();
    this.createInput();
    this.createAudio();
    this.createSimulation();
    this.bindDomControls();
    this.updateMenuCopy();
    this.renderState(this.simulation.getState());
  }

  public update(_time: number, delta: number): void {
    if (!this.runStarted) return;

    const input: SimulationInput = {
      keys: {
        w: this.keys.w.isDown,
        a: this.keys.a.isDown,
        s: this.keys.s.isDown,
        d: this.keys.d.isDown,
        arrowup: this.keys.up.isDown,
        arrowleft: this.keys.left.isDown,
        arrowdown: this.keys.down.isDown,
        arrowright: this.keys.right.isDown,
        space: this.keys.space.isDown,
      },
      pointer: { ...this.pointer, down: this.pointerDown },
    };
    this.simulation.advance(delta, input);
    const state = this.simulation.getState();
    this.consumeEvents(this.simulation.drainEvents());
    this.renderState(state);
    this.updateHud(state);
  }

  private createBackgrounds(): void {
    this.menuBackground = this.add.image(WIDTH / 2, HEIGHT / 2, "menu-background").setDisplaySize(WIDTH, HEIGHT).setDepth(-100);
    this.arenaBackground = this.add.image(WIDTH / 2, HEIGHT / 2, "arena-background").setDisplaySize(WIDTH, HEIGHT).setDepth(-100).setVisible(false);
    this.logo = this.add.image(WIDTH / 2, 132, "logo").setDisplaySize(360, 180).setDepth(-10);
    this.add.rectangle(WIDTH / 2, HEIGHT / 2, WIDTH - 86, HEIGHT - 86, COLORS.background, 0.08).setStrokeStyle(2, COLORS.accent, 0.35).setDepth(-5);
    this.aimGraphic = this.add.graphics().setDepth(5);
  }

  private createAnimations(): void {
    if (!this.anims.exists("explosion")) {
      this.anims.create({
        key: "explosion",
        frames: this.anims.generateFrameNames("explosion-atlas", { prefix: "frame-", start: 0, end: 3 }),
        frameRate: 20,
        repeat: 0,
      });
    }
    if (!this.anims.exists("impact")) {
      this.anims.create({
        key: "impact",
        frames: this.anims.generateFrameNames("impact-atlas", { prefix: "frame-", start: 0, end: 3 }),
        frameRate: 24,
        repeat: 0,
      });
    }
  }

  private createInput(): void {
    const keyboard = this.input.keyboard;
    if (!keyboard) throw new Error("Vector Siege requires keyboard input");
    this.keys = {
      w: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W),
      a: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A),
      s: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S),
      d: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D),
      up: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.UP),
      left: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.LEFT),
      down: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.DOWN),
      right: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.RIGHT),
      space: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE),
      pause: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.P),
    };
    keyboard.addCapture([Phaser.Input.Keyboard.KeyCodes.SPACE, Phaser.Input.Keyboard.KeyCodes.UP, Phaser.Input.Keyboard.KeyCodes.DOWN, Phaser.Input.Keyboard.KeyCodes.LEFT, Phaser.Input.Keyboard.KeyCodes.RIGHT]);
    this.keys.pause.on("down", () => this.togglePause());
    this.input.on("pointermove", (pointer: Phaser.Input.Pointer) => {
      this.pointer = { x: pointer.worldX, y: pointer.worldY };
    });
    this.input.on("pointerdown", (pointer: Phaser.Input.Pointer) => {
      this.pointer = { x: pointer.worldX, y: pointer.worldY };
      if (pointer.leftButtonDown()) this.pointerDown = true;
    });
    this.input.on("pointerup", (pointer: Phaser.Input.Pointer) => {
      this.pointer = { x: pointer.worldX, y: pointer.worldY };
      if (pointer.button === 0) this.pointerDown = false;
    });
  }

  private createAudio(): void {
    this.sound.setMute(this.settings.muted);
    this.sound.setVolume(1);
    this.menuMusic = this.sound.add("menu-theme", { loop: true, volume: this.settings.musicVolume });
    this.gameplayMusic = this.sound.add("gameplay-loop", { loop: true, volume: this.settings.musicVolume });
    this.menuMusic.play();
  }

  private createSimulation(): void {
    this.simulation = new VectorSiegeSimulation({
      seed: seedFromLocation(),
      arena: { width: WIDTH, height: HEIGHT },
      playerStart: { x: WIDTH / 2, y: HEIGHT / 2 },
      playerMaxHealth: 50,
      playerSpeed: 260,
      spawnRadius: 300,
      initialEnemiesPerWave: 3,
      waveEnemyGrowth: 2,
    });
    this.simulationState = this.simulation.getState();
  }

  private bindDomControls(): void {
    element<HTMLButtonElement>("start-game").addEventListener("click", () => this.startRun());
    element<HTMLButtonElement>("audio-unlock").addEventListener("click", () => this.unlockAudio());
    element<HTMLButtonElement>("pause-game").addEventListener("click", () => this.pauseRun());
    element<HTMLButtonElement>("resume-game").addEventListener("click", () => this.resumeRun());
    element<HTMLButtonElement>("mute-toggle").addEventListener("click", () => this.toggleMute());
    element<HTMLButtonElement>("restart-game").addEventListener("click", () => this.restartRun());
    element<HTMLButtonElement>("game-over-restart").addEventListener("click", () => this.restartRun());
  }

  private startRun(): void {
    if (this.runStarted && this.simulationState.status === "running") return;
    this.runStarted = true;
    this.simulation.start();
    this.simulationState = this.simulation.getState();
    this.menuBackground.setVisible(false);
    this.arenaBackground.setVisible(true);
    this.logo.setVisible(false);
    this.menuMusic?.stop();
    this.gameplayMusic?.play();
    element<HTMLElement>("menu-panel").classList.add("hidden");
    element<HTMLElement>("hud").classList.remove("hidden");
    if (!this.audioUnlocked) element<HTMLElement>("audio-panel").classList.remove("hidden");
    this.updateHud(this.simulationState);
  }

  private unlockAudio(): void {
    this.audioUnlocked = true;
    this.sound.resumeAll();
    if (!this.gameplayMusic?.isPlaying && this.runStarted) this.gameplayMusic?.play();
    element<HTMLElement>("audio-panel").classList.add("hidden");
  }

  private pauseRun(): void {
    if (!this.runStarted || this.simulationState.status !== "running") return;
    this.simulation.pause();
    this.simulationState = this.simulation.getState();
    this.sound.pauseAll();
    element<HTMLElement>("pause-overlay").classList.remove("hidden");
    element<HTMLButtonElement>("pause-game").classList.add("hidden");
    element<HTMLButtonElement>("resume-game").classList.remove("hidden");
  }

  private resumeRun(): void {
    if (!this.runStarted || this.simulationState.status !== "paused") return;
    this.simulation.resume();
    this.simulationState = this.simulation.getState();
    this.sound.resumeAll();
    element<HTMLElement>("pause-overlay").classList.add("hidden");
    element<HTMLButtonElement>("pause-game").classList.remove("hidden");
    element<HTMLButtonElement>("resume-game").classList.add("hidden");
  }

  private togglePause(): void {
    if (this.simulationState.status === "paused") this.resumeRun();
    else this.pauseRun();
  }

  private toggleMute(): void {
    this.settings.muted = !this.settings.muted;
    this.sound.setMute(this.settings.muted);
    writeSettings(this.settings);
    const muteButton = element<HTMLButtonElement>("mute-toggle");
    muteButton.setAttribute("aria-pressed", String(this.settings.muted));
    muteButton.textContent = this.settings.muted ? "Sound off" : "Sound on";
  }

  private restartRun(): void {
    this.runStarted = true;
    this.simulation.restart(seedFromLocation());
    this.simulationState = this.simulation.getState();
    this.menuBackground.setVisible(false);
    this.arenaBackground.setVisible(true);
    this.logo.setVisible(false);
    this.gameplayMusic?.stop();
    this.gameplayMusic?.play();
    this.clearEntitySprites();
    element<HTMLElement>("menu-panel").classList.add("hidden");
    element<HTMLElement>("hud").classList.remove("hidden");
    element<HTMLElement>("pause-overlay").classList.add("hidden");
    element<HTMLElement>("game-over").classList.add("hidden");
    element<HTMLButtonElement>("pause-game").classList.remove("hidden");
    element<HTMLButtonElement>("resume-game").classList.add("hidden");
    this.updateHud(this.simulationState);
  }

  private consumeEvents(events: SimulationEvent[]): void {
    for (const event of events) {
      if (event.type === "shot") this.playEffect("shoot");
      if (event.type === "enemy-hit") {
        this.playEffect("enemy-hit");
        const enemy = this.enemySprites.get(event.enemyId);
        if (enemy) this.playImpact(enemy.x, enemy.y);
      }
      if (event.type === "enemy-defeated") {
        this.playEffect("enemy-defeat");
        const position = this.lastEnemyPositions.get(event.enemyId);
        if (position) this.playExplosion(position.x, position.y);
      }
      if (event.type === "player-damaged") this.playEffect("player-hit");
      if (event.type === "wave-started" && event.wave > 1) this.playEffect("wave-start");
      if (event.type === "game-over") {
        this.playEffect("game-over");
        this.gameplayMusic?.stop();
        this.settings.highScore = Math.max(this.settings.highScore, event.terminal.score);
        writeSettings(this.settings);
        element<HTMLElement>("game-over").classList.remove("hidden");
        element<HTMLElement>("final-score-copy").textContent = `Run complete — score ${event.terminal.score}, wave ${event.terminal.wave}, tick ${event.terminal.finalTick}.`;
      }
    }
  }

  private playEffect(key: string): void {
    if (this.settings.muted) return;
    this.sound.play(key, { volume: this.settings.effectsVolume });
  }

  private playExplosion(x: number, y: number): void {
    const effect = this.add.sprite(x, y, "explosion-atlas", "frame-0").setDisplaySize(82, 82).setDepth(4);
    effect.once(Phaser.Animations.Events.ANIMATION_COMPLETE, () => effect.destroy());
    effect.play("explosion");
  }

  private playImpact(x: number, y: number): void {
    const effect = this.add.sprite(x, y, "impact-atlas", "frame-0").setDisplaySize(64, 64).setDepth(4);
    effect.once(Phaser.Animations.Events.ANIMATION_COMPLETE, () => effect.destroy());
    effect.play("impact");
  }

  private renderState(state: SimulationState): void {
    this.simulationState = state;
    this.lastEnemyPositions.clear();
    for (const enemy of state.enemies) this.lastEnemyPositions.set(enemy.id, { x: enemy.x, y: enemy.y });
    this.renderPlayer(state);
    this.renderAim(state);
    this.renderEnemies(state.enemies);
    this.renderProjectiles(state);
  }

  private renderPlayer(state: SimulationState): void {
    if (!this.playerSprite) {
      this.playerSprite = this.add.image(state.player.x, state.player.y, "player").setDisplaySize(68, 68).setDepth(3);
    }
    this.playerSprite.setPosition(state.player.x, state.player.y);
    const blinking = state.player.invulnerableTicks > 0 && Math.floor(state.tick / 3) % 2 === 0;
    this.playerSprite.setAlpha(blinking ? 0.35 : 1);
  }

  private renderAim(state: SimulationState): void {
    this.aimGraphic.clear();
    if (!this.runStarted || state.status !== "running") return;
    this.aimGraphic.lineStyle(1, COLORS.accent, 0.16);
    this.aimGraphic.beginPath();
    this.aimGraphic.moveTo(state.player.x, state.player.y);
    this.aimGraphic.lineTo(this.pointer.x, this.pointer.y);
    this.aimGraphic.strokePath();
    this.aimGraphic.lineStyle(1, COLORS.accent, 0.5);
    this.aimGraphic.strokeCircle(this.pointer.x, this.pointer.y, 10);
    this.aimGraphic.strokeCircle(this.pointer.x, this.pointer.y, 3);
  }

  private renderEnemies(enemies: EnemyState[]): void {
    const active = new Set(enemies.map((enemy) => enemy.id));
    for (const [id, sprite] of this.enemySprites) {
      if (!active.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
        this.enemyHealthBars.get(id)?.destroy();
        this.enemyHealthBars.delete(id);
      }
    }
    for (const enemy of enemies) {
      const texture = enemy.variant === "chaser" ? "enemy-chaser" : enemy.variant === "striker" ? "enemy-striker" : "enemy-tank";
      const size = enemy.variant === "tank" ? 82 : 62;
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.add.image(enemy.x, enemy.y, texture).setDisplaySize(size, size).setDepth(2);
        this.enemySprites.set(enemy.id, sprite);
        const bar = this.add.rectangle(enemy.x, enemy.y - size / 2 - 8, size, 4, COLORS.danger, 0.9).setOrigin(0.5).setDepth(3);
        this.enemyHealthBars.set(enemy.id, bar);
      }
      sprite.setPosition(enemy.x, enemy.y);
      const bar = this.enemyHealthBars.get(enemy.id);
      if (bar) {
        bar.setPosition(enemy.x, enemy.y - size / 2 - 8);
        bar.setDisplaySize(size * clamp(enemy.health / enemy.maxHealth, 0, 1), 4);
        bar.setFillStyle(enemy.variant === "tank" ? COLORS.highlight : COLORS.danger, 0.9);
      }
    }
  }

  private renderProjectiles(state: SimulationState): void {
    const active = new Set(state.projectiles.map((projectile) => projectile.id));
    for (const [id, sprite] of this.projectileSprites) {
      if (!active.has(id)) {
        sprite.destroy();
        this.projectileSprites.delete(id);
      }
    }
    for (const projectile of state.projectiles) {
      let sprite = this.projectileSprites.get(projectile.id);
      if (!sprite) {
        sprite = this.add.circle(projectile.x, projectile.y, 6, COLORS.accent, 1).setDepth(3);
        this.projectileSprites.set(projectile.id, sprite);
      }
      sprite.setPosition(projectile.x, projectile.y);
    }
  }

  private updateHud(state: SimulationState): void {
    element<HTMLElement>("score").textContent = `Score: ${state.score}`;
    element<HTMLElement>("wave").textContent = `Wave: ${state.wave}`;
    element<HTMLElement>("health").textContent = `Hull: ${state.player.health} / ${state.player.maxHealth}`;
  }

  private updateMenuCopy(): void {
    element<HTMLElement>("high-score-copy").textContent = this.settings.highScore > 0 ? `Local high score: ${this.settings.highScore}` : "No run recorded yet";
    const muteButton = element<HTMLButtonElement>("mute-toggle");
    muteButton.setAttribute("aria-pressed", String(this.settings.muted));
    muteButton.textContent = this.settings.muted ? "Sound off" : "Sound on";
  }

  private clearEntitySprites(): void {
    this.enemySprites.forEach((sprite) => sprite.destroy());
    this.enemyHealthBars.forEach((bar) => bar.destroy());
    this.projectileSprites.forEach((sprite) => sprite.destroy());
    this.enemySprites.clear();
    this.enemyHealthBars.clear();
    this.projectileSprites.clear();
    this.lastEnemyPositions.clear();
  }
}

new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  backgroundColor: COLORS.background,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: WIDTH,
    height: HEIGHT,
  },
  render: {
    antialias: true,
    roundPixels: true,
  },
  fps: {
    target: 60,
    smoothStep: false,
  },
  input: {
    keyboard: true,
    mouse: true,
    touch: true,
    activePointers: 1,
  },
  scene: ArenaScene,
});
