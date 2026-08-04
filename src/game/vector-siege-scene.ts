import Phaser from "phaser";
import {
  type EnemyKind,
  type EnemyState,
  type InputFrame,
  type SimulationEvent,
  type SimulationState,
  VectorSiegeSimulation,
} from "../shared-simulation/simulation";

interface AudioPreferences {
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
  highScore: number;
}

interface VectorSiegeBridge {
  getState: () => SimulationState | null;
  getNearestEnemy: () => EnemyState | null;
  start: () => void;
  restart: () => void;
  toggleMute: () => boolean;
  getAudioPreferences: () => AudioPreferences;
}

declare global {
  interface Window {
    __VECTOR_SIEGE__?: VectorSiegeBridge;
  }
}

const WIDTH = 1280;
const HEIGHT = 720;
const FIXED_STEP_MS = 1000 / 60;
const SETTINGS_KEY = "vector-siege-settings-v1";

const COLORS = {
  background: 0x08111f,
  panel: 0x0d1c2e,
  panelLight: 0x132941,
  accent: 0x49dcb1,
  danger: 0xff4f78,
  highlight: 0xf6c453,
  muted: 0x61728b,
  white: 0xf4f8ff,
};

const TEXT = {
  heading: {
    fontFamily: "Arial, Helvetica, sans-serif",
    fontStyle: "bold",
    color: "#f4f8ff",
    letterSpacing: 2,
  },
  body: {
    fontFamily: "Arial, Helvetica, sans-serif",
    color: "#d6e4f5",
    letterSpacing: 1,
  },
  label: {
    fontFamily: "Arial, Helvetica, sans-serif",
    fontStyle: "bold",
    color: "#49dcb1",
    letterSpacing: 1,
  },
};

export class VectorSiegeScene extends Phaser.Scene {
  private simulation!: VectorSiegeSimulation;
  private screen: "menu" | "running" | "paused" | "gameover" = "menu";
  private rootLayer!: Phaser.GameObjects.Container;
  private worldLayer!: Phaser.GameObjects.Container;
  private projectileGraphics!: Phaser.GameObjects.Graphics;
  private entityEffects!: Phaser.GameObjects.Graphics;
  private aimGraphics!: Phaser.GameObjects.Graphics;
  private damageOverlay!: Phaser.GameObjects.Rectangle;
  private playerSprite?: Phaser.GameObjects.Image;
  private readonly enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private readonly effectSprites: Array<{ sprite: Phaser.GameObjects.Sprite; age: number; duration: number }> = [];
  private scoreText?: Phaser.GameObjects.Text;
  private waveText?: Phaser.GameObjects.Text;
  private healthText?: Phaser.GameObjects.Text;
  private statusText?: Phaser.GameObjects.Text;
  private highScoreText?: Phaser.GameObjects.Text;
  private muteButton?: Phaser.GameObjects.Container;
  private preferences: AudioPreferences = { musicVolume: 0.42, effectsVolume: 0.58, muted: false, highScore: 0 };
  private music?: Phaser.Sound.BaseSound;
  private musicKey?: "menu-theme" | "gameplay-loop";
  private audioUnlocked = false;
  private pointerHeld = false;
  private accumulator = 0;
  private keys: Record<string, { isDown: boolean }> = {};

  public constructor() {
    super("vector-siege");
  }

  public preload(): void {
    const base = "/benchmark-assets/vector-siege";
    this.load.image("menu-background", `${base}/visuals/menu-background.webp`);
    this.load.image("arena-background", `${base}/visuals/arena-background.webp`);
    this.load.image("logo", `${base}/visuals/logo.webp`);
    this.load.image("player", `${base}/visuals/player.webp`);
    this.load.image("enemy-chaser", `${base}/visuals/enemies/chaser.webp`);
    this.load.image("enemy-tank", `${base}/visuals/enemies/tank.webp`);
    this.load.image("enemy-striker", `${base}/visuals/enemies/striker.webp`);
    this.load.image("pickup-health", `${base}/visuals/pickups/health.webp`);
    this.load.image("pickup-rapid-fire", `${base}/visuals/pickups/rapid-fire.webp`);
    this.load.image("ui-heart", `${base}/visuals/ui/heart.webp`);
    this.load.image("ui-score", `${base}/visuals/ui/score.webp`);
    this.load.image("ui-wave", `${base}/visuals/ui/wave.webp`);
    this.load.atlas("explosion", `${base}/visuals/effects/explosion-atlas.webp`, `${base}/visuals/effects/explosion-atlas.json`);
    this.load.atlas("impact", `${base}/visuals/effects/impact-atlas.webp`, `${base}/visuals/effects/impact-atlas.json`);
    this.load.audio("menu-theme", `${base}/audio/menu-theme.mp3`);
    this.load.audio("gameplay-loop", `${base}/audio/gameplay-loop.mp3`);
    this.load.audio("shoot", `${base}/audio/shoot.wav`);
    this.load.audio("enemy-hit", `${base}/audio/enemy-hit.wav`);
    this.load.audio("player-hit", `${base}/audio/player-hit.wav`);
    this.load.audio("enemy-defeat", `${base}/audio/enemy-defeat.wav`);
    this.load.audio("wave-start", `${base}/audio/wave-start.wav`);
    this.load.audio("game-over", `${base}/audio/game-over.wav`);
  }

  public create(): void {
    this.preferences = this.readPreferences();
    this.simulation = new VectorSiegeSimulation(this.readSeed());
    this.rootLayer = this.add.container(0, 0);
    this.installInput();
    this.installBridge();
    this.showMenu();
    this.updateAccessibility();
    const canvas = this.game.canvas;
    canvas.id = "vector-siege-canvas";
    canvas.dataset.testid = "vector-siege-canvas";
    canvas.setAttribute("aria-label", "Vector Siege arena shooter");
    canvas.setAttribute("role", "application");
  }

  public update(_time: number, delta: number): void {
    if (this.screen !== "running") return;
    this.accumulator += Math.min(delta, 100);
    let steps = 0;
    while (this.accumulator >= FIXED_STEP_MS && steps < 8) {
      this.accumulator -= FIXED_STEP_MS;
      const result = this.simulation.step(this.readInput());
      this.handleEvents(result.events);
      steps += 1;
      if (this.screen !== "running") return;
    }
    this.updateEffects();
    this.renderRunningState();
  }

  private installInput(): void {
    const keyboard = this.input.keyboard;
    if (keyboard) {
      this.keys = keyboard.addKeys({
        up: Phaser.Input.Keyboard.KeyCodes.W,
        down: Phaser.Input.Keyboard.KeyCodes.S,
        left: Phaser.Input.Keyboard.KeyCodes.A,
        right: Phaser.Input.Keyboard.KeyCodes.D,
        arrowUp: Phaser.Input.Keyboard.KeyCodes.UP,
        arrowDown: Phaser.Input.Keyboard.KeyCodes.DOWN,
        arrowLeft: Phaser.Input.Keyboard.KeyCodes.LEFT,
        arrowRight: Phaser.Input.Keyboard.KeyCodes.RIGHT,
        space: Phaser.Input.Keyboard.KeyCodes.SPACE,
      }) as Record<string, { isDown: boolean }>;
      keyboard.on("keydown-ENTER", () => {
        if (this.screen === "menu" || this.screen === "gameover") this.startGame();
      });
      keyboard.on("keydown-P", () => {
        if (this.screen === "running") this.pauseGame();
        else if (this.screen === "paused") this.resumeGame();
      });
      keyboard.on("keydown-ESC", () => {
        if (this.screen === "running") this.pauseGame();
        else if (this.screen === "paused") this.resumeGame();
      });
      keyboard.on("keydown-M", () => this.toggleMute());
      keyboard.on("keydown-V", () => this.adjustVolumes(0.05));
    }

    this.input.on("pointerdown", () => {
      this.pointerHeld = true;
      this.unlockAudio();
    });
    this.input.on("pointerup", () => {
      this.pointerHeld = false;
    });
    this.input.on("pointerout", () => {
      this.pointerHeld = false;
    });
    this.input.setDefaultCursor("crosshair");
  }

  private installBridge(): void {
    window.__VECTOR_SIEGE__ = {
      getState: () => (this.simulation ? this.simulation.snapshot() : null),
      getNearestEnemy: () => {
        if (!this.simulation || this.simulation.state.enemies.length === 0) return null;
        const player = this.simulation.state.player;
        return [...this.simulation.state.enemies].sort(
          (left, right) =>
            (left.x - player.x) ** 2 + (left.y - player.y) ** 2 -
            ((right.x - player.x) ** 2 + (right.y - player.y) ** 2),
        )[0];
      },
      start: () => this.startGame(),
      restart: () => this.restartGame(),
      toggleMute: () => this.toggleMute(),
      getAudioPreferences: () => ({ ...this.preferences }),
    };
  }

  private showMenu(): void {
    this.screen = "menu";
    this.accumulator = 0;
    this.clearRoot();
    this.addBackground("menu-background");
    const dim = this.addGraphics();
    dim.fillStyle(COLORS.background, 0.38);
    dim.fillRect(0, 0, WIDTH, HEIGHT);
    const logo = this.addImage(WIDTH / 2, 154, "logo");
    logo.setDisplaySize(370, 185).setAlpha(0.94);
    this.addText(WIDTH / 2, 278, "VECTOR SIEGE", {
      ...TEXT.heading,
      fontSize: "42px",
      color: "#49dcb1",
      stroke: "#08111f",
      strokeThickness: 8,
    }).setOrigin(0.5);
    this.addText(WIDTH / 2, 324, "SOLO ARENA // STAGE 01", { ...TEXT.label, fontSize: "14px", color: "#d6e4f5" }).setOrigin(0.5);

    const panel = this.addGraphics();
    panel.fillStyle(COLORS.panel, 0.92);
    panel.fillRoundedRect(265, 365, 750, 248, 16);
    panel.lineStyle(2, COLORS.accent, 0.5);
    panel.strokeRoundedRect(265, 365, 750, 248, 16);
    this.addText(316, 394, "MISSION BRIEF", { ...TEXT.label, fontSize: "15px" });
    this.addText(316, 427, "Survive the signal storm. Clear each wave and keep the core online.", { ...TEXT.body, fontSize: "16px", color: "#f4f8ff" });
    this.addText(316, 468, "WASD / ARROWS", { ...TEXT.heading, fontSize: "13px", color: "#49dcb1" });
    this.addText(506, 468, "MOVE", { ...TEXT.body, fontSize: "13px" });
    this.addText(316, 494, "POINTER + CLICK", { ...TEXT.heading, fontSize: "13px", color: "#f6c453" });
    this.addText(506, 494, "AIM / FIRE", { ...TEXT.body, fontSize: "13px" });
    this.addText(704, 468, "SPACE", { ...TEXT.heading, fontSize: "13px", color: "#f6c453" });
    this.addText(787, 468, "FIRE", { ...TEXT.body, fontSize: "13px" });
    this.addText(704, 494, "P / ESC", { ...TEXT.heading, fontSize: "13px", color: "#49dcb1" });
    this.addText(787, 494, "PAUSE", { ...TEXT.body, fontSize: "13px" });
    const healthPickup = this.addImage(320, 550, "pickup-health");
    healthPickup.setDisplaySize(34, 34);
    const rapidPickup = this.addImage(366, 550, "pickup-rapid-fire");
    rapidPickup.setDisplaySize(34, 34);
    this.addText(410, 550, `HIGH SCORE  ${String(this.preferences.highScore).padStart(5, "0")}`, { ...TEXT.label, fontSize: "13px", color: "#f6c453" }).setOrigin(0, 0.5);
    this.addButton(741, 555, 242, 48, "START RUN  [ENTER]", COLORS.accent, () => this.startGame()).setDepth(4);
    const audioLabel = this.addText(640, 652, this.audioLabel(), { ...TEXT.body, fontSize: "13px", color: "#9eb1c8" }).setOrigin(0.5);
    audioLabel.setInteractive({ useHandCursor: true });
    audioLabel.on("pointerup", () => this.toggleMute());
    this.startMenuMusicIfUnlocked();
  }

  private startGame(): void {
    this.unlockAudio();
    this.simulation.start();
    this.screen = "running";
    this.accumulator = 0;
    this.showRunningScene();
    this.playMusic("gameplay-loop");
    this.playSfx("wave-start");
    this.updateAccessibility();
  }

  private restartGame(): void {
    this.unlockAudio();
    this.simulation.restart();
    this.screen = "running";
    this.accumulator = 0;
    this.showRunningScene();
    this.playMusic("gameplay-loop");
    this.playSfx("wave-start");
    this.updateAccessibility();
  }

  private showRunningScene(): void {
    this.clearRoot();
    this.addBackground("arena-background");
    this.worldLayer = this.add.container(0, 0);
    this.rootLayer.add(this.worldLayer);
    this.projectileGraphics = this.addGraphics();
    this.entityEffects = this.addGraphics();
    this.aimGraphics = this.addGraphics();
    this.worldLayer.add([this.projectileGraphics, this.entityEffects, this.aimGraphics]);
    this.damageOverlay = this.addRectangle(0, 0, WIDTH, HEIGHT, COLORS.danger, 0);
    this.damageOverlay.setOrigin(0, 0).setBlendMode(Phaser.BlendModes.ADD);
    this.rootLayer.add(this.damageOverlay);
    this.createHud();
    this.renderRunningState();
  }

  private createHud(): void {
    const header = this.addGraphics();
    header.fillStyle(COLORS.background, 0.86);
    header.fillRect(0, 0, WIDTH, 82);
    header.lineStyle(1, COLORS.accent, 0.28);
    header.lineBetween(0, 81, WIDTH, 81);
    this.addText(32, 20, "VECTOR SIEGE", { ...TEXT.heading, fontSize: "18px", color: "#49dcb1" });
    this.statusText = this.addText(32, 49, "SIGNAL LOCKED", { ...TEXT.label, fontSize: "11px", color: "#61728b" });
    const scoreIcon = this.addImage(315, 41, "ui-score");
    scoreIcon.setDisplaySize(30, 30);
    this.addText(346, 18, "SCORE", { ...TEXT.label, fontSize: "10px", color: "#61728b" });
    this.scoreText = this.addText(346, 37, "00000", { ...TEXT.heading, fontSize: "22px", color: "#f6c453" });
    const waveIcon = this.addImage(574, 41, "ui-wave");
    waveIcon.setDisplaySize(30, 30);
    this.addText(605, 18, "WAVE", { ...TEXT.label, fontSize: "10px", color: "#61728b" });
    this.waveText = this.addText(605, 37, "01", { ...TEXT.heading, fontSize: "22px", color: "#49dcb1" });
    const heartIcon = this.addImage(785, 41, "ui-heart");
    heartIcon.setDisplaySize(30, 30);
    this.addText(816, 18, "CORE", { ...TEXT.label, fontSize: "10px", color: "#61728b" });
    this.healthText = this.addText(816, 37, "3 / 3", { ...TEXT.heading, fontSize: "22px", color: "#ff4f78" });
    this.highScoreText = this.addText(1015, 21, `BEST  ${String(this.preferences.highScore).padStart(5, "0")}`, { ...TEXT.label, fontSize: "12px", color: "#f6c453" });
    this.muteButton = this.addButton(1114, 45, 128, 32, this.muteButtonLabel(), COLORS.panelLight, () => this.toggleMute());
    this.muteButton.setScale(0.9);
    const footer = this.addGraphics();
    footer.fillStyle(COLORS.background, 0.75);
    footer.fillRect(0, 675, WIDTH, 45);
    footer.lineStyle(1, COLORS.accent, 0.18);
    footer.lineBetween(0, 675, WIDTH, 675);
    this.addText(32, 696, "WASD / ARROWS MOVE", { ...TEXT.label, fontSize: "11px", color: "#9eb1c8" });
    this.addText(274, 696, "POINTER AIM", { ...TEXT.label, fontSize: "11px", color: "#9eb1c8" });
    this.addText(472, 696, "CLICK / SPACE FIRE", { ...TEXT.label, fontSize: "11px", color: "#9eb1c8" });
    this.addText(1038, 696, "P  PAUSE", { ...TEXT.label, fontSize: "11px", color: "#49dcb1" });
  }

  private renderRunningState(): void {
    if (!this.playerSprite) {
      this.playerSprite = this.addImage(0, 0, "player");
      this.playerSprite.setDisplaySize(56, 56);
      this.worldLayer.add(this.playerSprite);
    }
    const state = this.simulation.state;
    this.playerSprite.setPosition(state.player.x, state.player.y);
    this.playerSprite.setRotation(this.pointerAngle() + Math.PI / 4);
    this.playerSprite.setAlpha(state.player.invulnerableTicks > 0 ? 0.48 + Math.sin(state.tick * 0.55) * 0.2 : 1);
    const presentIds = new Set<number>();
    this.entityEffects.clear();
    for (const enemy of state.enemies) {
      presentIds.add(enemy.id);
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.addImage(enemy.x, enemy.y, this.enemyTexture(enemy.kind));
        const size = enemy.kind === "tank" ? 66 : enemy.kind === "striker" ? 52 : 56;
        sprite.setDisplaySize(size, size);
        this.worldLayer.add(sprite);
        this.enemySprites.set(enemy.id, sprite);
      }
      sprite.setPosition(enemy.x, enemy.y);
      sprite.setRotation(Math.atan2(state.player.y - enemy.y, state.player.x - enemy.x) + Math.PI / 4);
      sprite.setAlpha(enemy.hitFlashTicks > 0 ? 0.52 : 1);
      const healthRatio = enemy.health / enemy.maxHealth;
      const barWidth = enemy.kind === "tank" ? 54 : 44;
      this.entityEffects.fillStyle(0x091321, 0.9);
      this.entityEffects.fillRect(enemy.x - barWidth / 2, enemy.y - enemy.radius - 12, barWidth, 4);
      this.entityEffects.fillStyle(enemy.kind === "tank" ? COLORS.highlight : COLORS.danger, 1);
      this.entityEffects.fillRect(enemy.x - barWidth / 2, enemy.y - enemy.radius - 12, barWidth * healthRatio, 4);
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!presentIds.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
      }
    }
    this.projectileGraphics.clear();
    for (const projectile of state.projectiles) {
      this.projectileGraphics.fillStyle(COLORS.highlight, 0.18);
      this.projectileGraphics.fillCircle(projectile.x, projectile.y, 11);
      this.projectileGraphics.fillStyle(COLORS.white, 1);
      this.projectileGraphics.fillCircle(projectile.x, projectile.y, projectile.radius);
    }
    const pointer = this.input.activePointer;
    const aimX = Phaser.Math.Clamp(pointer.worldX, 0, WIDTH);
    const aimY = Phaser.Math.Clamp(pointer.worldY, 0, HEIGHT);
    this.aimGraphics.clear();
    this.aimGraphics.lineStyle(1, COLORS.accent, 0.72);
    this.aimGraphics.strokeCircle(aimX, aimY, 12);
    this.aimGraphics.lineBetween(aimX - 18, aimY, aimX - 7, aimY);
    this.aimGraphics.lineBetween(aimX + 7, aimY, aimX + 18, aimY);
    this.aimGraphics.lineBetween(aimX, aimY - 18, aimX, aimY - 7);
    this.aimGraphics.lineBetween(aimX, aimY + 7, aimX, aimY + 18);
    this.damageOverlay.setAlpha(state.player.hitFlashTicks > 0 ? 0.12 : 0);
    this.scoreText?.setText(String(state.score).padStart(5, "0"));
    this.waveText?.setText(String(state.wave).padStart(2, "0"));
    this.healthText?.setText(`${state.player.health} / ${state.player.maxHealth}`);
    this.statusText?.setText(state.player.invulnerableTicks > 0 ? "IMPACT ABSORBED" : "SIGNAL LOCKED");
    this.highScoreText?.setText(`BEST  ${String(Math.max(this.preferences.highScore, state.score)).padStart(5, "0")}`);
    this.setMuteButtonLabel();
    this.updateAccessibility();
  }

  private handleEvents(events: SimulationEvent[]): void {
    for (const event of events) {
      if (event.type === "shot") this.playSfx("shoot");
      else if (event.type === "enemy-hit") {
        this.playSfx("enemy-hit");
        this.addImpactEffect(event.x, event.y, "impact");
      } else if (event.type === "enemy-defeated") {
        this.playSfx("enemy-defeat");
        this.addImpactEffect(event.x, event.y, "explosion");
      } else if (event.type === "player-hit") this.playSfx("player-hit");
      else if (event.type === "wave-started") this.playSfx("wave-start");
      else if (event.type === "game-over") this.finishGameOver();
    }
  }

  private finishGameOver(): void {
    if (this.screen === "gameover") return;
    this.screen = "gameover";
    this.stopMusic();
    this.playSfx("game-over");
    this.preferences.highScore = Math.max(this.preferences.highScore, this.simulation.state.score);
    this.savePreferences();
    this.showGameOver();
    this.updateAccessibility();
  }

  private showGameOver(): void {
    this.clearRoot();
    this.addBackground("arena-background");
    const overlay = this.addGraphics();
    overlay.fillStyle(COLORS.background, 0.78);
    overlay.fillRect(0, 0, WIDTH, HEIGHT);
    overlay.fillStyle(COLORS.danger, 0.08);
    overlay.fillCircle(WIDTH / 2, HEIGHT / 2 - 70, 280);
    this.addText(WIDTH / 2, 158, "SIGNAL LOST", { ...TEXT.heading, fontSize: "46px", color: "#ff4f78" }).setOrigin(0.5);
    this.addText(WIDTH / 2, 212, "THE SIEGE BREACHED THE CORE", { ...TEXT.label, fontSize: "13px", color: "#d6e4f5" }).setOrigin(0.5);
    const panel = this.addGraphics();
    panel.fillStyle(COLORS.panel, 0.95);
    panel.fillRoundedRect(400, 268, 480, 240, 18);
    panel.lineStyle(2, COLORS.danger, 0.62);
    panel.strokeRoundedRect(400, 268, 480, 240, 18);
    this.addText(640, 307, "FINAL READOUT", { ...TEXT.label, fontSize: "14px" }).setOrigin(0.5);
    this.addText(510, 355, "SCORE", { ...TEXT.body, fontSize: "14px", color: "#9eb1c8" });
    this.addText(770, 355, String(this.simulation.state.score).padStart(5, "0"), { ...TEXT.heading, fontSize: "24px", color: "#f6c453" }).setOrigin(1, 0);
    this.addText(510, 393, "WAVE", { ...TEXT.body, fontSize: "14px", color: "#9eb1c8" });
    this.addText(770, 393, String(this.simulation.state.wave).padStart(2, "0"), { ...TEXT.heading, fontSize: "24px", color: "#49dcb1" }).setOrigin(1, 0);
    this.addText(510, 431, "RUN SEED", { ...TEXT.body, fontSize: "14px", color: "#9eb1c8" });
    this.addText(770, 431, String(this.simulation.state.seed), { ...TEXT.heading, fontSize: "17px", color: "#f4f8ff" }).setOrigin(1, 0);
    this.addText(510, 466, "FINAL TICK", { ...TEXT.body, fontSize: "14px", color: "#9eb1c8" });
    this.addText(770, 466, String(this.simulation.state.tick), { ...TEXT.heading, fontSize: "17px", color: "#f4f8ff" }).setOrigin(1, 0);
    this.addButton(640, 580, 290, 52, "RESTART RUN  [ENTER]", COLORS.accent, () => this.restartGame());
    this.addText(640, 656, `BEST SCORE  ${String(this.preferences.highScore).padStart(5, "0")}   •   M TOGGLE MUTE`, { ...TEXT.body, fontSize: "13px", color: "#9eb1c8" }).setOrigin(0.5);
  }

  private pauseGame(): void {
    if (this.screen !== "running") return;
    this.simulation.pause();
    this.screen = "paused";
    this.pauseMusic();
    const overlay = this.addGraphics();
    overlay.fillStyle(COLORS.background, 0.74);
    overlay.fillRect(0, 0, WIDTH, HEIGHT);
    overlay.setDepth(20);
    const panel = this.addGraphics();
    panel.fillStyle(COLORS.panel, 0.98);
    panel.fillRoundedRect(430, 240, 420, 240, 18);
    panel.lineStyle(2, COLORS.accent, 0.7);
    panel.strokeRoundedRect(430, 240, 420, 240, 18);
    panel.setDepth(21);
    const title = this.addText(640, 287, "RUN PAUSED", { ...TEXT.heading, fontSize: "34px", color: "#49dcb1" }).setOrigin(0.5);
    title.setDepth(22);
    const subtitle = this.addText(640, 332, "THE CORE IS HOLDING", { ...TEXT.label, fontSize: "12px", color: "#d6e4f5" }).setOrigin(0.5);
    subtitle.setDepth(22);
    this.addButton(640, 405, 230, 48, "RESUME  [P]", COLORS.accent, () => this.resumeGame()).setDepth(22);
    const hint = this.addText(640, 452, "M TOGGLE MUTE", { ...TEXT.body, fontSize: "12px", color: "#9eb1c8" }).setOrigin(0.5);
    hint.setDepth(22);
    this.updateAccessibility();
  }

  private resumeGame(): void {
    if (this.screen !== "paused") return;
    this.simulation.resume();
    this.screen = "running";
    this.removePauseOverlay();
    this.resumeMusic();
    this.updateAccessibility();
  }

  private removePauseOverlay(): void {
    for (const child of this.rootLayer.list.filter((child) => {
      const depth = (child as unknown as { depth?: number }).depth;
      return depth !== undefined && depth >= 20;
    })) {
      child.destroy();
    }
  }

  private toggleMute(): boolean {
    this.unlockAudio();
    this.preferences.muted = !this.preferences.muted;
    this.applyAudioPreferences();
    this.savePreferences();
    if (this.preferences.muted) this.pauseMusic();
    else if (this.screen === "menu") this.playMusic("menu-theme");
    else if (this.screen === "running") this.playMusic("gameplay-loop");
    if (this.screen === "menu") this.showMenu();
    else if (this.screen === "running") this.setMuteButtonLabel();
    this.updateAccessibility();
    return this.preferences.muted;
  }

  private adjustVolumes(amount: number): void {
    this.preferences.musicVolume = Phaser.Math.Clamp(this.preferences.musicVolume + amount, 0, 1);
    this.preferences.effectsVolume = Phaser.Math.Clamp(this.preferences.effectsVolume + amount, 0, 1);
    this.applyAudioPreferences();
    this.savePreferences();
    if (this.screen === "menu") this.showMenu();
  }

  private applyAudioPreferences(): void {
    const sound = this.sound as unknown as { mute: boolean; volume: number };
    sound.mute = this.preferences.muted;
    sound.volume = 1;
    const music = this.music as unknown as { setVolume?: (volume: number) => void } | undefined;
    music?.setVolume?.(this.preferences.musicVolume);
  }

  private playMusic(key: "menu-theme" | "gameplay-loop"): void {
    if (!this.audioUnlocked || this.preferences.muted) return;
    if (this.musicKey === key && this.music) {
      if (this.music.isPaused) this.music.resume();
      return;
    }
    this.stopMusic();
    this.musicKey = key;
    this.music = this.sound.add(key, { loop: true, volume: this.preferences.musicVolume });
    this.music.play();
  }

  private startMenuMusicIfUnlocked(): void {
    if (this.audioUnlocked) this.playMusic("menu-theme");
  }

  private pauseMusic(): void {
    if (this.music?.isPlaying) this.music.pause();
  }

  private resumeMusic(): void {
    if (!this.preferences.muted && this.music?.isPaused) this.music.resume();
  }

  private stopMusic(): void {
    if (this.music) {
      this.music.stop();
      this.music.destroy();
    }
    this.music = undefined;
    this.musicKey = undefined;
  }

  private playSfx(key: string): void {
    if (!this.audioUnlocked || this.preferences.muted) return;
    this.sound.play(key, { volume: this.preferences.effectsVolume });
  }

  private unlockAudio(): void {
    this.audioUnlocked = true;
    const sound = this.sound as unknown as { unlock?: () => void; resume?: () => void };
    sound.unlock?.();
    sound.resume?.();
    this.applyAudioPreferences();
    this.startMenuMusicIfUnlocked();
  }

  private addImpactEffect(x: number, y: number, atlas: "impact" | "explosion"): void {
    const sprite = this.add.sprite(x, y, atlas, "frame-0");
    const size = atlas === "explosion" ? 86 : 64;
    sprite.setDisplaySize(size, size).setDepth(6);
    this.worldLayer.add(sprite);
    this.effectSprites.push({ sprite, age: 0, duration: atlas === "explosion" ? 18 : 10 });
  }

  private updateEffects(): void {
    for (let index = this.effectSprites.length - 1; index >= 0; index -= 1) {
      const effect = this.effectSprites[index];
      effect.age += 1;
      const ratio = effect.age / effect.duration;
      effect.sprite.setFrame(`frame-${Math.min(3, Math.floor(ratio * 4))}`);
      effect.sprite.setAlpha(1 - ratio);
      effect.sprite.setScale(0.8 + ratio * 0.45);
      if (effect.age >= effect.duration) {
        effect.sprite.destroy();
        this.effectSprites.splice(index, 1);
      }
    }
  }

  private clearRoot(): void {
    this.enemySprites.clear();
    this.effectSprites.length = 0;
    this.playerSprite = undefined;
    this.scoreText = undefined;
    this.waveText = undefined;
    this.healthText = undefined;
    this.statusText = undefined;
    this.highScoreText = undefined;
    this.muteButton = undefined;
    this.rootLayer.removeAll(true);
  }

  private addBackground(key: "menu-background" | "arena-background"): void {
    const image = this.addImage(0, 0, key);
    image.setOrigin(0, 0).setDisplaySize(WIDTH, HEIGHT);
    this.rootLayer.add(image);
  }

  private addGraphics(): Phaser.GameObjects.Graphics {
    const graphics = this.add.graphics();
    this.rootLayer.add(graphics);
    return graphics;
  }

  private addImage(x: number, y: number, key: string): Phaser.GameObjects.Image {
    const image = this.add.image(x, y, key);
    this.rootLayer.add(image);
    return image;
  }

  private addRectangle(x: number, y: number, width: number, height: number, color: number, alpha: number): Phaser.GameObjects.Rectangle {
    const rectangle = this.add.rectangle(x, y, width, height, color, alpha);
    this.rootLayer.add(rectangle);
    return rectangle;
  }

  private addText(x: number, y: number, content: string, style: Record<string, unknown>): Phaser.GameObjects.Text {
    const text = this.add.text(x, y, content, style);
    this.rootLayer.add(text);
    return text;
  }

  private addButton(x: number, y: number, width: number, height: number, label: string, color: number, action: () => void): Phaser.GameObjects.Container {
    const background = this.add.rectangle(0, 0, width, height, color, 1);
    background.setStrokeStyle(2, COLORS.white, 0.42);
    const text = this.add.text(0, 0, label, { ...TEXT.heading, fontSize: "14px", color: "#08111f" }).setOrigin(0.5);
    const button = this.add.container(x, y, [background, text]);
    button.setSize(width, height);
    button.setInteractive(new Phaser.Geom.Rectangle(-width / 2, -height / 2, width, height), Phaser.Geom.Rectangle.Contains);
    button.on("pointerover", () => {
      background.setAlpha(0.82);
      text.setScale(1.04);
    });
    button.on("pointerout", () => {
      background.setAlpha(1);
      text.setScale(1);
    });
    button.on("pointerup", action);
    this.rootLayer.add(button);
    return button;
  }

  private enemyTexture(kind: EnemyKind): string {
    return `enemy-${kind}`;
  }

  private pointerAngle(): number {
    const pointer = this.input.activePointer;
    return Math.atan2(pointer.worldY - this.simulation.state.player.y, pointer.worldX - this.simulation.state.player.x);
  }

  private readInput(): InputFrame {
    const pointer = this.input.activePointer;
    return {
      up: this.keys.up?.isDown || this.keys.arrowUp?.isDown || false,
      down: this.keys.down?.isDown || this.keys.arrowDown?.isDown || false,
      left: this.keys.left?.isDown || this.keys.arrowLeft?.isDown || false,
      right: this.keys.right?.isDown || this.keys.arrowRight?.isDown || false,
      fire: this.pointerHeld || Boolean(this.keys.space?.isDown),
      aimX: pointer.worldX,
      aimY: pointer.worldY,
    };
  }

  private audioLabel(): string {
    const percent = Math.round(this.preferences.musicVolume * 100);
    return `${this.preferences.muted ? "SOUND OFF" : "SOUND ON"}   •   MUSIC ${percent}%   •   M TOGGLE`;
  }

  private muteButtonLabel(): string {
    return this.preferences.muted ? "SOUND  OFF" : "SOUND  ON";
  }

  private setMuteButtonLabel(): void {
    const label = this.muteButton?.getAt(1) as Phaser.GameObjects.Text | undefined;
    label?.setText(this.muteButtonLabel());
  }

  private readPreferences(): AudioPreferences {
    try {
      const raw = window.localStorage.getItem(SETTINGS_KEY);
      if (!raw) return { ...this.preferences };
      const parsed = JSON.parse(raw) as Partial<AudioPreferences>;
      const musicVolume = Number(parsed.musicVolume);
      const effectsVolume = Number(parsed.effectsVolume);
      return {
        musicVolume: Phaser.Math.Clamp(Number.isFinite(musicVolume) ? musicVolume : 0.42, 0, 1),
        effectsVolume: Phaser.Math.Clamp(Number.isFinite(effectsVolume) ? effectsVolume : 0.58, 0, 1),
        muted: Boolean(parsed.muted),
        highScore: Math.max(0, Math.floor(Number(parsed.highScore) || 0)),
      };
    } catch (error) {
      console.warn("Vector Siege preferences could not be read; using defaults.", error);
      return { ...this.preferences };
    }
  }

  private savePreferences(): void {
    try {
      window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(this.preferences));
    } catch (error) {
      console.warn("Vector Siege preferences could not be saved.", error);
    }
  }

  private readSeed(): number {
    const rawSeed = new URLSearchParams(window.location.search).get("seed");
    if (!rawSeed) return 0x51e697e;
    const seed = Number(rawSeed);
    return Number.isFinite(seed) ? seed : 0x51e697e;
  }

  private updateAccessibility(): void {
    const status = document.getElementById("screen-reader-status");
    if (!status || !this.simulation) return;
    const state = this.simulation.state;
    const screenLabel = this.screen === "menu" ? "start screen" : this.screen;
    status.textContent = `Vector Siege ${screenLabel}. Score ${state.score}. Wave ${state.wave}. Core ${state.player.health} of ${state.player.maxHealth}. ${this.preferences.muted ? "Sound muted." : "Sound on."}`;
  }
}
