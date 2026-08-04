import Phaser from "phaser";
import {
  DEFAULT_SIMULATION_CONFIG,
  EMPTY_INPUT,
  type EnemyKind,
  type EnemyState,
  type InputFrame,
  type SimulationEvent,
  type SimulationState,
  VectorSiegeSimulation,
} from "../shared-simulation/vector-siege-simulation";

const WIDTH = DEFAULT_SIMULATION_CONFIG.width;
const HEIGHT = DEFAULT_SIMULATION_CONFIG.height;
const FIXED_STEP_MS = 1000 / 60;
const ASSET_ROOT = "/benchmark-assets/vector-siege";

const COLORS = {
  accent: 0x49dcb1,
  background: 0x08111f,
  danger: 0xff4f78,
  highlight: 0xf6c453,
  muted: 0x61728b,
  white: 0xf3f7ff,
  ink: 0x0b1727,
};

type ScreenMode = "menu" | "playing" | "paused" | "game-over";

interface Preferences {
  highScore: number;
  musicVolume: number;
  effectsVolume: number;
  mute: boolean;
}

interface MusicLike {
  play: () => boolean;
  pause: () => boolean;
  resume: () => boolean;
  stop: () => boolean;
  setVolume: (value: number) => unknown;
  isPlaying: boolean;
  isPaused: boolean;
}

interface UiElements {
  overlay: HTMLElement;
  menuPanel: HTMLElement;
  pausePanel: HTMLElement;
  gameOverPanel: HTMLElement;
  hud: HTMLElement;
  startButton: HTMLButtonElement;
  resumeButton: HTMLButtonElement;
  restartButton: HTMLButtonElement;
  pauseMenuButton: HTMLButtonElement;
  gameOverMenuButton: HTMLButtonElement;
  pauseButton: HTMLButtonElement;
  muteButton: HTMLButtonElement;
  volumeSlider: HTMLInputElement;
  volumeValue: HTMLElement;
  effectsSlider: HTMLInputElement;
  effectsValue: HTMLElement;
  seedInput: HTMLInputElement;
  screenTitle: HTMLElement;
  score: HTMLElement;
  wave: HTMLElement;
  health: HTMLElement;
  highScore: HTMLElement;
  status: HTMLElement;
  finalScore: HTMLElement;
  finalWave: HTMLElement;
  finalTick: HTMLElement;
  finalSeed: HTMLElement;
}

function readPreferences(): Preferences {
  const defaults: Preferences = {
    highScore: 0,
    musicVolume: 0.32,
    effectsVolume: 0.5,
    mute: false,
  };
  try {
    const raw = window.localStorage.getItem("vector-siege-preferences");
    if (!raw) {
      return defaults;
    }
    const parsed = JSON.parse(raw) as Partial<Preferences>;
    return {
      highScore: Number.isFinite(parsed.highScore) ? Math.max(0, Number(parsed.highScore)) : defaults.highScore,
      musicVolume: Number.isFinite(parsed.musicVolume) ? Math.min(1, Math.max(0, Number(parsed.musicVolume))) : defaults.musicVolume,
      effectsVolume: Number.isFinite(parsed.effectsVolume) ? Math.min(1, Math.max(0, Number(parsed.effectsVolume))) : defaults.effectsVolume,
      mute: parsed.mute === true,
    };
  } catch {
    return defaults;
  }
}

function savePreferences(preferences: Preferences): void {
  try {
    window.localStorage.setItem("vector-siege-preferences", JSON.stringify(preferences));
  } catch {
    // Storage can be disabled in private browsing; the game remains playable.
  }
}

function element<T extends HTMLElement>(id: string): T {
  const found = document.getElementById(id);
  if (!found) {
    throw new Error(`Missing Vector Siege UI element: ${id}`);
  }
  return found as T;
}

function collectUi(): UiElements {
  return {
    overlay: element("ui-overlay"),
    menuPanel: element("menu-panel"),
    pausePanel: element("pause-panel"),
    gameOverPanel: element("game-over-panel"),
    hud: element("game-hud"),
    startButton: element<HTMLButtonElement>("start-game"),
    resumeButton: element<HTMLButtonElement>("resume-game"),
    restartButton: element<HTMLButtonElement>("restart-game"),
    pauseMenuButton: element<HTMLButtonElement>("back-to-menu-pause"),
    gameOverMenuButton: element<HTMLButtonElement>("back-to-menu-gameover"),
    pauseButton: element<HTMLButtonElement>("pause-game"),
    muteButton: element<HTMLButtonElement>("mute-toggle"),
    volumeSlider: element<HTMLInputElement>("music-volume"),
    volumeValue: element("music-volume-value"),
    effectsSlider: element<HTMLInputElement>("effects-volume"),
    effectsValue: element("effects-volume-value"),
    seedInput: element<HTMLInputElement>("seed-input"),
    screenTitle: element("screen-title"),
    score: element("score-value"),
    wave: element("wave-value"),
    health: element("health-value"),
    highScore: element("high-score-value"),
    status: element("game-status-menu"),
    finalScore: element("final-score"),
    finalWave: element("final-wave"),
    finalTick: element("final-tick"),
    finalSeed: element("final-seed"),
  };
}

function enemyTexture(kind: EnemyKind): string {
  if (kind === "tank") {
    return "enemy-tank";
  }
  if (kind === "striker") {
    return "enemy-striker";
  }
  return "enemy-chaser";
}

function displayName(kind: EnemyKind): string {
  return kind.charAt(0).toUpperCase() + kind.slice(1);
}

export class VectorSiegeScene extends Phaser.Scene {
  private preferences: Preferences = readPreferences();
  private ui!: UiElements;
  private mode: ScreenMode = "menu";
  private simulation: VectorSiegeSimulation | null = null;
  private accumulator = 0;
  private pointerEngaged = false;

  private menuBackground?: Phaser.GameObjects.Image;
  private arenaBackground?: Phaser.GameObjects.Image;
  private logo?: Phaser.GameObjects.Image;
  private worldLayer?: Phaser.GameObjects.Container;
  private hudLayer?: Phaser.GameObjects.Container;
  private hudBar?: Phaser.GameObjects.Graphics;
  private crosshair?: Phaser.GameObjects.Graphics;
  private damageOverlay?: Phaser.GameObjects.Graphics;
  private playerSprite?: Phaser.GameObjects.Image;
  private readonly enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private readonly projectileSprites = new Map<number, Phaser.GameObjects.Arc>();
  private readonly effectSprites = new Set<Phaser.GameObjects.Sprite>();
  private scoreText?: Phaser.GameObjects.Text;
  private waveText?: Phaser.GameObjects.Text;
  private healthText?: Phaser.GameObjects.Text;
  private bannerText?: Phaser.GameObjects.Text;
  private statusText?: Phaser.GameObjects.Text;

  private upKey!: Phaser.Input.Keyboard.Key;
  private downKey!: Phaser.Input.Keyboard.Key;
  private leftKey!: Phaser.Input.Keyboard.Key;
  private rightKey!: Phaser.Input.Keyboard.Key;
  private wKey!: Phaser.Input.Keyboard.Key;
  private aKey!: Phaser.Input.Keyboard.Key;
  private sKey!: Phaser.Input.Keyboard.Key;
  private dKey!: Phaser.Input.Keyboard.Key;
  private spaceKey!: Phaser.Input.Keyboard.Key;
  private music: MusicLike | null = null;
  private musicKey: "menu-music" | "gameplay-music" | null = null;

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
    this.load.image("health-pickup", `${ASSET_ROOT}/visuals/pickups/health.webp`);
    this.load.image("rapid-fire-pickup", `${ASSET_ROOT}/visuals/pickups/rapid-fire.webp`);
    this.load.image("ui-heart", `${ASSET_ROOT}/visuals/ui/heart.webp`);
    this.load.image("ui-score", `${ASSET_ROOT}/visuals/ui/score.webp`);
    this.load.image("ui-wave", `${ASSET_ROOT}/visuals/ui/wave.webp`);
    this.load.atlas(
      "impact-atlas",
      `${ASSET_ROOT}/visuals/effects/impact-atlas.webp`,
      `${ASSET_ROOT}/visuals/effects/impact-atlas.json`,
    );
    this.load.atlas(
      "explosion-atlas",
      `${ASSET_ROOT}/visuals/effects/explosion-atlas.webp`,
      `${ASSET_ROOT}/visuals/effects/explosion-atlas.json`,
    );

    this.load.audio("menu-music", `${ASSET_ROOT}/audio/menu-theme.mp3`);
    this.load.audio("gameplay-music", `${ASSET_ROOT}/audio/gameplay-loop.mp3`);
    this.load.audio("shoot", `${ASSET_ROOT}/audio/shoot.wav`);
    this.load.audio("enemy-hit", `${ASSET_ROOT}/audio/enemy-hit.wav`);
    this.load.audio("player-hit", `${ASSET_ROOT}/audio/player-hit.wav`);
    this.load.audio("enemy-defeat", `${ASSET_ROOT}/audio/enemy-defeat.wav`);
    this.load.audio("wave-start", `${ASSET_ROOT}/audio/wave-start.wav`);
    this.load.audio("game-over", `${ASSET_ROOT}/audio/game-over.wav`);
  }

  public create(): void {
    this.ui = collectUi();
    this.setupAnimations();
    this.setupInput();
    this.setupSceneLayers();
    this.bindUi();
    this.setScreen("menu");
    this.updateMuteUi();
    this.updateVolumeUi();
    this.playMusic("menu-music");
    this.updateDomHud(null);
  }

  public update(_time: number, delta: number): void {
    if (this.mode !== "playing" || !this.simulation) {
      return;
    }

    this.accumulator += Math.min(250, Math.max(0, delta));
    while (this.accumulator >= FIXED_STEP_MS && this.simulation && this.mode === "playing") {
      this.simulation.step(this.readInput());
      this.processSimulationEvents(this.simulation.drainEvents());
      this.accumulator -= FIXED_STEP_MS;
    }

    if (this.simulation) {
      this.renderSimulation(this.simulation.state);
      this.updateDomHud(this.simulation.state);
    }
  }

  private setupAnimations(): void {
    this.anims.create({
      key: "impact-pop",
      frames: this.anims.generateFrameNames("impact-atlas", { prefix: "frame-", start: 0, end: 3 }),
      frameRate: 22,
      repeat: 0,
    });
    this.anims.create({
      key: "explosion-pop",
      frames: this.anims.generateFrameNames("explosion-atlas", { prefix: "frame-", start: 0, end: 3 }),
      frameRate: 18,
      repeat: 0,
    });
  }

  private setupInput(): void {
    const keyboard = this.input.keyboard;
    if (!keyboard) {
      throw new Error("Vector Siege requires keyboard input");
    }
    this.upKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.UP);
    this.downKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.DOWN);
    this.leftKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.LEFT);
    this.rightKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.RIGHT);
    this.wKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W);
    this.aKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A);
    this.sKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S);
    this.dKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D);
    this.spaceKey = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);
    keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.P);
    keyboard.addCapture(["W", "A", "S", "D", "UP", "DOWN", "LEFT", "RIGHT", "SPACE"]);
    keyboard.on("keydown-P", () => this.togglePause(), this);
    keyboard.on("keydown-ESC", () => this.togglePause(), this);
    this.input.on("pointerdown", () => {
      this.pointerEngaged = true;
      this.unlockAudio();
    }, this);
    this.input.on("pointermove", () => { this.pointerEngaged = true; }, this);
  }

  private setupSceneLayers(): void {
    this.menuBackground = this.add.image(WIDTH / 2, HEIGHT / 2, "menu-background").setDepth(-20);
    this.arenaBackground = this.add.image(WIDTH / 2, HEIGHT / 2, "arena-background").setDepth(-20).setVisible(false);
    this.menuBackground.setDisplaySize(WIDTH, HEIGHT);
    this.arenaBackground.setDisplaySize(WIDTH, HEIGHT);

    this.worldLayer = this.add.container(0, 0).setDepth(1);
    this.crosshair = this.add.graphics().setDepth(8);
    this.damageOverlay = this.add.graphics().setDepth(9);
    this.hudLayer = this.add.container(0, 0).setDepth(20);
    this.hudBar = this.add.graphics().setDepth(20);
    this.hudBar.fillStyle(COLORS.ink, 0.86).fillRect(0, 0, WIDTH, 92);
    this.hudBar.lineStyle(1, COLORS.accent, 0.22).lineBetween(0, 91, WIDTH, 91);
    this.hudLayer.add(this.hudBar);

    this.addHudMetric("ui-heart", 44, 40, "HEALTH", (text) => { this.healthText = text; });
    this.addHudMetric("ui-score", 272, 40, "SCORE", (text) => { this.scoreText = text; });
    this.addHudMetric("ui-wave", 500, 40, "WAVE", (text) => { this.waveText = text; });
    this.bannerText = this.add.text(WIDTH / 2, 42, "SIGNAL LOCKED", {
      color: "#49dcb1",
      fontFamily: "'Space Mono', monospace",
      fontSize: "16px",
      fontStyle: "bold",
      letterSpacing: 3,
    }).setOrigin(0.5).setAlpha(0.8);
    this.hudLayer.add(this.bannerText);
    this.statusText = this.add.text(WIDTH / 2, HEIGHT - 38, "CLICK OR PRESS SPACE TO FIRE", {
      color: "#a8bbd5",
      fontFamily: "'Space Mono', monospace",
      fontSize: "13px",
      letterSpacing: 2,
    }).setOrigin(0.5).setAlpha(0.78);
    this.hudLayer.add(this.statusText);
    this.hudLayer.setVisible(false);
  }

  private addHudMetric(
    texture: string,
    x: number,
    y: number,
    label: string,
    receiveText: (text: Phaser.GameObjects.Text) => void,
  ): void {
    const icon = this.add.image(x, y, texture).setDisplaySize(30, 30).setAlpha(0.95);
    const labelText = this.add.text(x + 25, y - 15, label, {
      color: "#61728b",
      fontFamily: "'Space Mono', monospace",
      fontSize: "10px",
      fontStyle: "bold",
      letterSpacing: 1,
    });
    const valueText = this.add.text(x + 25, y + 4, "--", {
      color: "#f3f7ff",
      fontFamily: "'Space Mono', monospace",
      fontSize: "18px",
      fontStyle: "bold",
    });
    this.hudLayer?.add([icon, labelText, valueText]);
    receiveText(valueText);
  }

  private bindUi(): void {
    this.ui.seedInput.value = new URLSearchParams(window.location.search).get("seed") ?? "stage-1";
    this.ui.volumeSlider.value = String(Math.round(this.preferences.musicVolume * 100));
    this.ui.startButton.addEventListener("click", () => {
      this.unlockAudio();
      this.startGame(this.ui.seedInput.value.trim() || "stage-1");
    });
    this.ui.resumeButton.addEventListener("click", () => {
      this.unlockAudio();
      this.resumeGame();
    });
    this.ui.restartButton.addEventListener("click", () => {
      this.unlockAudio();
      this.startGame((this.simulation?.state.seed ?? this.ui.seedInput.value.trim()) || "stage-1");
    });
    this.ui.pauseMenuButton.addEventListener("click", () => {
      this.unlockAudio();
      this.returnToMenu();
    });
    this.ui.gameOverMenuButton.addEventListener("click", () => {
      this.unlockAudio();
      this.returnToMenu();
    });
    this.ui.pauseButton.addEventListener("click", () => this.togglePause());
    this.ui.muteButton.addEventListener("click", () => this.toggleMute());
    this.ui.volumeSlider.addEventListener("input", () => {
      this.preferences.musicVolume = Number(this.ui.volumeSlider.value) / 100;
      this.updateVolumeUi();
      this.applyMusicPreferences();
      savePreferences(this.preferences);
    });
    this.ui.effectsSlider.addEventListener("input", () => {
      this.preferences.effectsVolume = Number(this.ui.effectsSlider.value) / 100;
      this.updateVolumeUi();
      savePreferences(this.preferences);
    });
  }

  private startGame(seed: string): void {
    this.stopOneShot("game-over");
    this.simulation = new VectorSiegeSimulation(seed, DEFAULT_SIMULATION_CONFIG);
    this.accumulator = 0;
    this.pointerEngaged = false;
    this.mode = "playing";
    this.setScreen("playing");
    this.setBackground("arena");
    this.clearRenderedCombat();
    this.playMusic("gameplay-music");
    this.renderSimulation(this.simulation.state);
    this.updateDomHud(this.simulation.state);
  }

  private returnToMenu(): void {
    this.mode = "menu";
    this.simulation = null;
    this.accumulator = 0;
    this.clearRenderedCombat();
    this.setBackground("menu");
    this.setScreen("menu");
    this.playMusic("menu-music");
    this.updateDomHud(null);
  }

  private togglePause(): void {
    if (!this.simulation || this.mode === "game-over" || this.mode === "menu") {
      return;
    }
    if (this.mode === "playing") {
      this.simulation.pause();
      this.mode = "paused";
      this.music?.pause();
      this.setScreen("paused");
      this.updateDomHud(this.simulation.state);
      return;
    }
    this.resumeGame();
  }

  private resumeGame(): void {
    if (!this.simulation || this.mode !== "paused") {
      return;
    }
    this.simulation.resume();
    this.mode = "playing";
    this.music?.resume();
    this.setScreen("playing");
  }

  private toggleMute(): void {
    this.preferences.mute = !this.preferences.mute;
    this.applyMusicPreferences();
    this.updateMuteUi();
    savePreferences(this.preferences);
  }

  private setScreen(screen: ScreenMode): void {
    this.mode = screen;
    this.ui.menuPanel.hidden = screen !== "menu";
    this.ui.pausePanel.hidden = screen !== "paused";
    this.ui.gameOverPanel.hidden = screen !== "game-over";
    this.ui.hud.hidden = screen === "menu";
    this.ui.pauseButton.hidden = screen !== "playing";
    this.ui.overlay.dataset.screen = screen;
    this.ui.screenTitle.textContent = screen === "playing" ? "LIVE" : screen === "paused" ? "PAUSED" : screen === "game-over" ? "MISSION ENDED" : "VECTOR SIEGE";
    this.hudLayer?.setVisible(screen !== "menu");
  }

  private setBackground(background: "menu" | "arena"): void {
    this.menuBackground?.setVisible(background === "menu");
    this.arenaBackground?.setVisible(background === "arena");
  }

  private readInput(): InputFrame {
    const pointer = this.input.activePointer;
    const player = this.simulation?.state.player;
    const aimX = this.pointerEngaged && Number.isFinite(pointer.worldX) ? pointer.worldX : player?.position.x ?? EMPTY_INPUT.aimX;
    const aimY = this.pointerEngaged && Number.isFinite(pointer.worldY) ? pointer.worldY : player?.position.y ?? EMPTY_INPUT.aimY;
    return {
      up: this.upKey.isDown || this.wKey.isDown,
      down: this.downKey.isDown || this.sKey.isDown,
      left: this.leftKey.isDown || this.aKey.isDown,
      right: this.rightKey.isDown || this.dKey.isDown,
      fire: pointer.isDown || this.spaceKey.isDown,
      aimX,
      aimY,
    };
  }

  private renderSimulation(state: SimulationState): void {
    this.renderPlayer(state);
    this.renderEnemies(state.enemies);
    this.renderProjectiles(state.projectiles);
    this.renderCrosshair(state);
    this.renderDamageFeedback(state);
    this.scoreText?.setText(String(state.score).padStart(5, "0"));
    this.waveText?.setText(String(state.wave).padStart(2, "0"));
    this.healthText?.setText(`${state.player.health} / ${state.player.maxHealth}`);
    this.bannerText?.setText(state.player.invulnerableTicks > 0 ? "IMPACT ABSORBED" : "SIGNAL LOCKED");
    this.statusText?.setText(state.wavePauseTicksRemaining > 0 ? "WAVE CLEARED • NEXT SIGNAL INBOUND" : "CLICK OR PRESS SPACE TO FIRE");
  }

  private renderPlayer(state: SimulationState): void {
    if (!this.playerSprite) {
      this.playerSprite = this.add.image(0, 0, "player").setDisplaySize(76, 76).setDepth(7);
      this.worldLayer?.add(this.playerSprite);
    }
    const { player } = state;
    this.playerSprite.setPosition(player.position.x, player.position.y).setRotation(player.facing);
    const blinking = player.invulnerableTicks > 0 && Math.floor(player.invulnerableTicks / 4) % 2 === 0;
    this.playerSprite.setAlpha(blinking ? 0.32 : 1);
  }

  private renderEnemies(enemies: EnemyState[]): void {
    const activeIds = new Set<number>();
    for (const enemy of enemies) {
      activeIds.add(enemy.id);
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.add.image(enemy.position.x, enemy.position.y, enemyTexture(enemy.kind)).setDisplaySize(enemy.kind === "tank" ? 78 : 68, enemy.kind === "tank" ? 78 : 68).setDepth(5);
        this.enemySprites.set(enemy.id, sprite);
        this.worldLayer?.add(sprite);
      }
      sprite.setPosition(enemy.position.x, enemy.position.y);
      sprite.setAlpha(enemy.hitFlashTicks > 0 && enemy.hitFlashTicks % 2 === 0 ? 0.45 : 1);
      sprite.setRotation(enemy.kind === "striker" ? Math.sin((this.simulation?.state.tick ?? 0) / 18) * 0.14 : 0);
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!activeIds.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
      }
    }
  }

  private renderProjectiles(projectiles: SimulationState["projectiles"]): void {
    const activeIds = new Set<number>();
    for (const projectile of projectiles) {
      activeIds.add(projectile.id);
      let sprite = this.projectileSprites.get(projectile.id);
      if (!sprite) {
        sprite = this.add.circle(projectile.position.x, projectile.position.y, 6, COLORS.accent, 1).setDepth(6);
        this.projectileSprites.set(projectile.id, sprite);
        this.worldLayer?.add(sprite);
      }
      sprite.setPosition(projectile.position.x, projectile.position.y);
    }
    for (const [id, sprite] of this.projectileSprites) {
      if (!activeIds.has(id)) {
        sprite.destroy();
        this.projectileSprites.delete(id);
      }
    }
  }

  private renderCrosshair(state: SimulationState): void {
    if (!this.crosshair) {
      return;
    }
    const pointer = this.input.activePointer;
    const x = this.pointerEngaged && Number.isFinite(pointer.worldX) ? pointer.worldX : state.player.position.x + Math.cos(state.player.facing) * 180;
    const y = this.pointerEngaged && Number.isFinite(pointer.worldY) ? pointer.worldY : state.player.position.y + Math.sin(state.player.facing) * 180;
    const player = state.player.position;
    this.crosshair.clear();
    this.crosshair.lineStyle(1, COLORS.accent, 0.28).lineBetween(player.x, player.y, x, y);
    this.crosshair.lineStyle(2, COLORS.accent, 0.9).strokeCircle(x, y, 10);
    this.crosshair.lineStyle(1, COLORS.white, 0.82).lineBetween(x - 16, y, x - 4, y).lineBetween(x + 4, y, x + 16, y).lineBetween(x, y - 16, x, y - 4).lineBetween(x, y + 4, x, y + 16);
  }

  private renderDamageFeedback(state: SimulationState): void {
    if (!this.damageOverlay) {
      return;
    }
    this.damageOverlay.clear();
    if (state.player.hitFlashTicks > 0) {
      this.damageOverlay.fillStyle(COLORS.danger, Math.min(0.24, state.player.hitFlashTicks / 72));
      this.damageOverlay.fillRect(0, 0, WIDTH, HEIGHT);
      this.damageOverlay.lineStyle(3, COLORS.danger, 0.8).strokeRect(10, 10, WIDTH - 20, HEIGHT - 20);
    }
  }

  private processSimulationEvents(events: SimulationEvent[]): void {
    for (const event of events) {
      if (event.type === "shot") {
        this.playEffect("shoot");
      } else if (event.type === "enemy-hit") {
        this.playEffect("enemy-hit");
        const enemy = this.simulation?.state.enemies.find((candidate) => candidate.id === event.enemyId);
        if (enemy) {
          this.spawnEffect(enemy.position.x, enemy.position.y, "impact-atlas", "impact-pop", 0.95);
        }
      } else if (event.type === "enemy-defeated") {
        this.playEffect("enemy-defeat");
        const enemySprite = this.enemySprites.get(event.enemyId);
        if (enemySprite) {
          this.spawnEffect(enemySprite.x, enemySprite.y, "explosion-atlas", "explosion-pop", event.kind === "tank" ? 1.6 : 1.25);
        }
        if (this.simulation && this.simulation.state.score > this.preferences.highScore) {
          this.preferences.highScore = this.simulation.state.score;
          savePreferences(this.preferences);
        }
      } else if (event.type === "player-hit") {
        this.playEffect("player-hit");
        this.cameras.main.shake(140, 0.006);
      } else if (event.type === "wave-started") {
        this.playEffect("wave-start");
        this.bannerText?.setText(`WAVE ${String(event.wave).padStart(2, "0")} INBOUND`);
      } else if (event.type === "game-over") {
        this.finishGame(event.seed, event.finalTick);
      }
    }
  }

  private finishGame(seed: string, finalTick: number): void {
    if (!this.simulation) {
      return;
    }
    this.mode = "game-over";
    this.setScreen("game-over");
    this.music?.stop();
    this.playEffect("game-over");
    this.preferences.highScore = Math.max(this.preferences.highScore, this.simulation.state.score);
    savePreferences(this.preferences);
    this.ui.finalScore.textContent = String(this.simulation.state.score).padStart(5, "0");
    this.ui.finalWave.textContent = String(this.simulation.state.wave).padStart(2, "0");
    this.ui.finalTick.textContent = String(finalTick);
    this.ui.finalSeed.textContent = seed;
    try {
      window.localStorage.setItem("vector-siege-last-completion", JSON.stringify({ seed, finalTick }));
    } catch {
      // Completion is still available on the deterministic simulation state.
    }
  }

  private clearRenderedCombat(): void {
    this.playerSprite?.destroy();
    this.playerSprite = undefined;
    for (const sprite of this.enemySprites.values()) {
      sprite.destroy();
    }
    this.enemySprites.clear();
    for (const sprite of this.projectileSprites.values()) {
      sprite.destroy();
    }
    this.projectileSprites.clear();
    for (const sprite of this.effectSprites) {
      sprite.destroy();
    }
    this.effectSprites.clear();
    this.crosshair?.clear();
    this.damageOverlay?.clear();
  }

  private spawnEffect(x: number, y: number, atlas: string, animation: string, scale: number): void {
    const sprite = this.add.sprite(x, y, atlas, "frame-0").setScale(scale).setDepth(11);
    this.effectSprites.add(sprite);
    this.worldLayer?.add(sprite);
    sprite.once("animationcomplete", () => {
      this.effectSprites.delete(sprite);
      sprite.destroy();
    });
    sprite.play(animation);
  }

  private updateDomHud(state: SimulationState | null): void {
    this.ui.highScore.textContent = String(Math.max(this.preferences.highScore, state?.score ?? 0)).padStart(5, "0");
    if (!state) {
      this.ui.score.textContent = "00000";
      this.ui.wave.textContent = "01";
      this.ui.health.textContent = "5 / 5";
      this.ui.status.textContent = "READY FOR DEPLOYMENT";
      return;
    }
    this.ui.score.textContent = String(state.score).padStart(5, "0");
    this.ui.wave.textContent = String(state.wave).padStart(2, "0");
    this.ui.health.textContent = `${state.player.health} / ${state.player.maxHealth}`;
    this.ui.status.textContent = state.phase === "game-over" ? "MISSION ENDED" : state.wavePauseTicksRemaining > 0 ? "NEXT WAVE INBOUND" : "SIGNAL LOCKED";
  }

  private updateMuteUi(): void {
    const label = this.preferences.mute ? "UNMUTE" : "MUTE";
    this.ui.muteButton.textContent = label;
    this.ui.muteButton.setAttribute("aria-label", this.preferences.mute ? "Unmute audio" : "Mute audio");
    this.ui.muteButton.dataset.muted = String(this.preferences.mute);
  }

  private updateVolumeUi(): void {
    this.ui.volumeSlider.value = String(Math.round(this.preferences.musicVolume * 100));
    this.ui.volumeValue.textContent = `${Math.round(this.preferences.musicVolume * 100)}%`;
    this.ui.effectsSlider.value = String(Math.round(this.preferences.effectsVolume * 100));
    this.ui.effectsValue.textContent = `${Math.round(this.preferences.effectsVolume * 100)}%`;
  }

  private applyMusicPreferences(): void {
    this.sound.setMute(this.preferences.mute);
    this.music?.setVolume(this.preferences.musicVolume);
  }

  private unlockAudio(): void {
    const soundWithContext = this.sound as unknown as { locked?: boolean; context?: AudioContext };
    if (soundWithContext.locked && soundWithContext.context?.state === "suspended") {
      void soundWithContext.context.resume().catch(() => undefined);
    }
  }

  private playMusic(key: "menu-music" | "gameplay-music"): void {
    if (this.musicKey === key && this.music) {
      this.applyMusicPreferences();
      if (this.music.isPaused) {
        this.music.resume();
      } else if (!this.music.isPlaying) {
        this.music.play();
      }
      return;
    }
    this.music?.stop();
    this.musicKey = key;
    this.music = this.sound.add(key, { loop: true, volume: this.preferences.musicVolume }) as unknown as MusicLike;
    this.applyMusicPreferences();
    const tryPlay = (): void => {
      if (this.musicKey === key && this.music && !this.music.isPlaying) {
        this.music.play();
      }
    };
    const soundWithLock = this.sound as unknown as { locked?: boolean };
    if (soundWithLock.locked) {
      this.sound.once("unlocked", tryPlay, this);
    } else {
      tryPlay();
    }
  }

  private playEffect(key: string): void {
    const soundWithLock = this.sound as unknown as { locked?: boolean };
    if (soundWithLock.locked) {
      return;
    }
    this.sound.play(key, { volume: this.preferences.effectsVolume });
  }

  private stopOneShot(key: string): void {
    this.sound.stopByKey(key);
  }
}
