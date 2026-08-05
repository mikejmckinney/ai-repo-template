import Phaser from "phaser";
import { Simulation } from "../shared-simulation";
import type {
  EnemyKind,
  SimulationController,
  SimulationEvent,
  SimulationSnapshot,
  StepInput,
} from "../shared-simulation/types";
import { AudioController, type SoundManagerLike } from "./audio";
import { ASSET_ROOT, COLORS, DEFAULT_SEED, FIXED_STEP_MS, GAME_HEIGHT, GAME_WIDTH } from "./constants";
import { GameUi } from "./dom-ui";
import { loadHighScore, saveHighScore } from "./persistence";

interface KeyMap {
  up: Phaser.Input.Keyboard.Key;
  down: Phaser.Input.Keyboard.Key;
  left: Phaser.Input.Keyboard.Key;
  right: Phaser.Input.Keyboard.Key;
  arrowUp: Phaser.Input.Keyboard.Key;
  arrowDown: Phaser.Input.Keyboard.Key;
  arrowLeft: Phaser.Input.Keyboard.Key;
  arrowRight: Phaser.Input.Keyboard.Key;
  space: Phaser.Input.Keyboard.Key;
  pause: Phaser.Input.Keyboard.Key;
}

interface VectorPoint {
  x: number;
  y: number;
}

export class ArenaScene extends Phaser.Scene {
  private readonly ui: GameUi;
  private readonly seed: string;
  private simulation!: SimulationController;
  private audio!: AudioController;
  private keys!: KeyMap;
  private accumulator = 0;
  private pointerHeld = false;
  private pointerPosition: VectorPoint = { x: GAME_WIDTH / 2, y: GAME_HEIGHT / 2 };
  private highScore = 0;

  private menuBackground!: Phaser.GameObjects.Image;
  private arenaBackground!: Phaser.GameObjects.Image;
  private menuLogo!: Phaser.GameObjects.Image;
  private arenaDecor!: Phaser.GameObjects.Graphics;
  private aimLayer!: Phaser.GameObjects.Graphics;
  private healthBars!: Phaser.GameObjects.Graphics;
  private playerSprite!: Phaser.GameObjects.Image;
  private playerGlow!: Phaser.GameObjects.Arc;
  private readonly enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private readonly projectileSprites = new Map<number, Phaser.GameObjects.Arc>();

  public constructor(ui: GameUi, seed = readSeed()) {
    super({ key: "ArenaScene" });
    this.ui = ui;
    this.seed = seed;
  }

  public preload(): void {
    this.load.image("menu-background", `${ASSET_ROOT}/visuals/menu-background.webp`);
    this.load.image("arena-background", `${ASSET_ROOT}/visuals/arena-background.webp`);
    this.load.image("logo", `${ASSET_ROOT}/visuals/logo.webp`);
    this.load.image("player", `${ASSET_ROOT}/visuals/player.webp`);
    this.load.image("enemy-chaser", `${ASSET_ROOT}/visuals/enemies/chaser.webp`);
    this.load.image("enemy-striker", `${ASSET_ROOT}/visuals/enemies/striker.webp`);
    this.load.image("enemy-tank", `${ASSET_ROOT}/visuals/enemies/tank.webp`);
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
    this.load.audio("menu-music", `${ASSET_ROOT}/audio/menu-theme.mp3`);
    this.load.audio("gameplay-music", `${ASSET_ROOT}/audio/gameplay-loop.mp3`);
    this.load.audio("shoot", `${ASSET_ROOT}/audio/shoot.wav`);
    this.load.audio("enemy-hit", `${ASSET_ROOT}/audio/enemy-hit.wav`);
    this.load.audio("enemy-defeat", `${ASSET_ROOT}/audio/enemy-defeat.wav`);
    this.load.audio("player-hit", `${ASSET_ROOT}/audio/player-hit.wav`);
    this.load.audio("wave-start", `${ASSET_ROOT}/audio/wave-start.wav`);
    this.load.audio("game-over", `${ASSET_ROOT}/audio/game-over.wav`);
  }

  public create(): void {
    this.simulation = new Simulation({ seed: this.seed });
    this.audio = new AudioController(this.sound as unknown as SoundManagerLike);
    this.highScore = loadHighScore();

    this.createWorld();
    this.createInput();
    this.ui.applyAudioSettings(this.audio.getSettings());
    this.ui.bind({
      onStart: () => this.startMission(),
      onPause: () => this.pauseMission(),
      onResume: () => this.resumeMission(),
      onMute: () => this.toggleMute(),
      onRestart: () => this.restartMission(),
      onMusicVolume: (value) => this.audio.setMusicVolume(value),
      onEffectsVolume: (value) => this.audio.setEffectsVolume(value),
    });
    this.audio.playMusic("menu");
    this.ui.update(this.simulation.snapshot(), this.highScore);
    this.renderSnapshot(this.simulation.snapshot());

    this.events.once("shutdown", () => {
      this.audio.stopMusic();
      this.enemySprites.clear();
      this.projectileSprites.clear();
    });
  }

  public update(_time: number, delta: number): void {
    const snapshot = this.simulation.snapshot();
    if (snapshot.phase === "running") {
      this.accumulator += Math.min(delta, 120);
      while (this.accumulator >= FIXED_STEP_MS && this.simulation.snapshot().phase === "running") {
        this.simulation.step(this.readInput());
        this.processEvents(this.simulation.drainEvents());
        this.accumulator -= FIXED_STEP_MS;
      }
    } else {
      this.accumulator = 0;
    }

    this.renderSnapshot(this.simulation.snapshot());
    this.handlePauseHotkey();
  }

  private createWorld(): void {
    this.menuBackground = this.add.image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "menu-background").setDepth(-20);
    this.arenaBackground = this.add.image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "arena-background").setDepth(-20);
    this.menuLogo = this.add.image(880, 176, "logo").setDisplaySize(360, 180).setDepth(-5);

    this.arenaDecor = this.add.graphics().setDepth(-4);
    this.arenaDecor.lineStyle(2, COLORS.accent, 0.38);
    this.arenaDecor.strokeRoundedRect(42, 112, GAME_WIDTH - 84, GAME_HEIGHT - 154, 18);
    this.arenaDecor.lineStyle(1, COLORS.muted, 0.18);
    for (let x = 86; x < GAME_WIDTH - 60; x += 64) this.arenaDecor.lineBetween(x, 130, x, GAME_HEIGHT - 60);
    for (let y = 150; y < GAME_HEIGHT - 40; y += 64) this.arenaDecor.lineBetween(60, y, GAME_WIDTH - 60, y);

    this.aimLayer = this.add.graphics().setDepth(3);
    this.healthBars = this.add.graphics().setDepth(9);
    this.playerGlow = this.add.circle(GAME_WIDTH / 2, GAME_HEIGHT / 2, 42, COLORS.accent, 0.08)
      .setStrokeStyle(1, COLORS.accent, 0.48)
      .setDepth(8);
    this.playerSprite = this.add.image(GAME_WIDTH / 2, GAME_HEIGHT / 2, "player")
      .setDisplaySize(68, 68)
      .setDepth(10);
  }

  private createInput(): void {
    const keyboard = this.input.keyboard;
    if (!keyboard) throw new Error("Vector Siege requires the Phaser keyboard input plugin.");
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
      pause: Phaser.Input.Keyboard.KeyCodes.P,
    }) as KeyMap;
    keyboard.addCapture(["SPACE", "UP", "DOWN", "LEFT", "RIGHT"]);

    this.input.on("pointermove", (pointer: Phaser.Input.Pointer) => {
      this.pointerPosition = { x: pointer.x, y: pointer.y };
    });
    this.input.on("pointerdown", (pointer: Phaser.Input.Pointer) => {
      this.pointerHeld = true;
      this.pointerPosition = { x: pointer.x, y: pointer.y };
    });
    this.input.on("pointerup", () => {
      this.pointerHeld = false;
    });
    this.input.on("pointerout", () => {
      this.pointerHeld = false;
    });
  }

  private startMission(): void {
    this.simulation.start();
    this.pointerHeld = false;
    this.accumulator = 0;
    this.audio.playMusic("gameplay");
    this.ui.update(this.simulation.snapshot(), this.highScore);
    this.processEvents(this.simulation.drainEvents());
  }

  private pauseMission(): void {
    if (this.simulation.snapshot().phase !== "running") return;
    this.simulation.pause();
    this.audio.pause();
    this.ui.update(this.simulation.snapshot(), this.highScore);
  }

  private resumeMission(): void {
    if (this.simulation.snapshot().phase !== "paused") return;
    this.simulation.resume();
    this.audio.resume();
    this.ui.update(this.simulation.snapshot(), this.highScore);
  }

  private restartMission(): void {
    this.simulation.restart(this.seed);
    if (this.simulation.snapshot().phase !== "running") this.simulation.start();
    this.pointerHeld = false;
    this.accumulator = 0;
    this.audio.playMusic("gameplay");
    this.ui.update(this.simulation.snapshot(), this.highScore);
    this.processEvents(this.simulation.drainEvents());
  }

  private toggleMute(): void {
    const muted = this.audio.toggleMute();
    this.ui.setMuted(muted);
  }

  private handlePauseHotkey(): void {
    if (!Phaser.Input.Keyboard.JustDown(this.keys.pause)) return;
    if (this.simulation.snapshot().phase === "running") this.pauseMission();
    else if (this.simulation.snapshot().phase === "paused") this.resumeMission();
  }

  private readInput(): StepInput {
    return {
      up: this.keys.up.isDown || this.keys.arrowUp.isDown,
      down: this.keys.down.isDown || this.keys.arrowDown.isDown,
      left: this.keys.left.isDown || this.keys.arrowLeft.isDown,
      right: this.keys.right.isDown || this.keys.arrowRight.isDown,
      fire: this.pointerHeld || this.keys.space.isDown,
      aimX: this.pointerPosition.x,
      aimY: this.pointerPosition.y,
    };
  }

  private processEvents(events: SimulationEvent[]): void {
    for (const event of events) {
      switch (event.type) {
        case "shot-fired":
          this.audio.playEffect("shoot");
          break;
        case "enemy-hit":
          this.audio.playEffect("enemy-hit");
          this.spawnEffect("impact", event.x, event.y, 0.72);
          break;
        case "enemy-defeated":
          this.audio.playEffect("enemy-defeat");
          this.spawnEffect("explosion", event.x, event.y, event.kind === "tank" ? 1.24 : 0.95);
          break;
        case "player-hit":
          this.audio.playEffect("player-hit");
          this.cameras.main.shake(140, 0.008);
          break;
        case "wave-start":
          this.audio.playEffect("wave-start");
          break;
        case "game-over":
          this.audio.stopMusic();
          this.audio.playEffect("game-over");
          this.highScore = saveHighScore(event.record.score);
          break;
      }
    }
  }

  private spawnEffect(texture: "impact" | "explosion", x: number, y: number, scale: number): void {
    const effect = this.add.sprite(x, y, texture, "frame-0").setDepth(7).setScale(scale).setAlpha(0.9);
    this.tweens.add({
      targets: effect,
      alpha: 0,
      scale: scale * 1.7,
      duration: texture === "explosion" ? 320 : 180,
      ease: "Cubic.Out",
      onComplete: () => effect.destroy(),
    });
  }

  private renderSnapshot(snapshot: SimulationSnapshot): void {
    const active = snapshot.phase !== "menu";
    this.menuBackground.setVisible(!active);
    this.menuLogo.setVisible(!active);
    this.arenaBackground.setVisible(active);
    this.arenaDecor.setVisible(active);
    this.playerSprite.setVisible(active);
    this.playerGlow.setVisible(active);

    this.playerSprite.setPosition(snapshot.player.x, snapshot.player.y);
    this.playerGlow.setPosition(snapshot.player.x, snapshot.player.y);
    this.playerSprite.setRotation(Math.atan2(this.pointerPosition.y - snapshot.player.y, this.pointerPosition.x - snapshot.player.x) + Math.PI / 4);
    this.playerGlow.setFillStyle(snapshot.player.hitFlashTicks > 0 ? COLORS.danger : COLORS.accent, 0.08);
    if (snapshot.player.hitFlashTicks > 0) this.playerSprite.setTint(COLORS.danger);
    else this.playerSprite.clearTint();

    this.aimLayer.clear();
    if (active) {
      this.aimLayer.lineStyle(1, COLORS.accent, 0.18);
      this.aimLayer.lineBetween(snapshot.player.x, snapshot.player.y, this.pointerPosition.x, this.pointerPosition.y);
      this.aimLayer.fillStyle(COLORS.accent, 0.7);
      this.aimLayer.fillCircle(this.pointerPosition.x, this.pointerPosition.y, 3);
    }

    this.renderEnemies(snapshot.enemies);
    this.renderProjectiles(snapshot.projectiles);
    this.ui.update(snapshot, this.highScore);
  }

  private renderEnemies(enemies: SimulationSnapshot["enemies"]): void {
    const seen = new Set<number>();
    this.healthBars.clear();
    for (const enemy of enemies) {
      seen.add(enemy.id);
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.add.image(enemy.x, enemy.y, enemyTexture(enemy.kind)).setDepth(6);
        this.enemySprites.set(enemy.id, sprite);
      }
      sprite.setPosition(enemy.x, enemy.y);
      sprite.setDisplaySize(enemySize(enemy.kind), enemySize(enemy.kind));
      sprite.setRotation(enemy.kind === "striker" ? enemy.phase : 0);
      if (enemy.health < enemy.maxHealth) {
        const width = 44;
        const ratio = Math.max(0, enemy.health / enemy.maxHealth);
        this.healthBars.fillStyle(COLORS.danger, 0.28);
        this.healthBars.fillRect(enemy.x - width / 2, enemy.y - enemy.radius - 10, width, 4);
        this.healthBars.fillStyle(enemy.kind === "tank" ? COLORS.highlight : COLORS.accent, 0.9);
        this.healthBars.fillRect(enemy.x - width / 2, enemy.y - enemy.radius - 10, width * ratio, 4);
      }
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!seen.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
      }
    }
  }

  private renderProjectiles(projectiles: SimulationSnapshot["projectiles"]): void {
    const seen = new Set<number>();
    for (const projectile of projectiles) {
      seen.add(projectile.id);
      let sprite = this.projectileSprites.get(projectile.id);
      if (!sprite) {
        sprite = this.add.circle(projectile.x, projectile.y, projectile.radius, COLORS.highlight, 1).setDepth(8);
        sprite.setStrokeStyle(2, COLORS.white, 0.8);
        this.projectileSprites.set(projectile.id, sprite);
      }
      sprite.setPosition(projectile.x, projectile.y);
    }
    for (const [id, sprite] of this.projectileSprites) {
      if (!seen.has(id)) {
        sprite.destroy();
        this.projectileSprites.delete(id);
      }
    }
  }
}

function enemyTexture(kind: EnemyKind): string {
  return `enemy-${kind}`;
}

function enemySize(kind: EnemyKind): number {
  if (kind === "tank") return 80;
  if (kind === "striker") return 60;
  return 68;
}

function readSeed(): string {
  if (typeof window === "undefined") return DEFAULT_SEED;
  return new URLSearchParams(window.location.search).get("seed") || DEFAULT_SEED;
}
