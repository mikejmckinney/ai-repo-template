import Phaser from "phaser";
import {
  ARENA_HEIGHT,
  ARENA_MARGIN,
  ARENA_WIDTH,
  ArenaSimulation,
  FIXED_STEP_MS,
  type CompletedGame,
  type EnemyKind,
  type SimulationEvent,
  type SimulationSnapshot,
} from "./simulation";

const ASSET_ROOT = "/benchmark-assets/vector-siege";

export interface ArenaSceneCallbacks {
  onEvent: (event: SimulationEvent) => void;
  onReady: (scene: ArenaScene) => void;
  onSnapshot: (snapshot: SimulationSnapshot) => void;
}

type KeyName = "up" | "down" | "left" | "right" | "fire";

export class ArenaScene extends Phaser.Scene {
  private readonly simulation = new ArenaSimulation();
  private callbacks: ArenaSceneCallbacks | null = null;
  private accumulator = 0;
  private readonly keyGroups: Partial<Record<KeyName, Phaser.Input.Keyboard.Key[]>> = {};
  private pointerFire = false;
  private aimX = ARENA_WIDTH / 2;
  private aimY = ARENA_HEIGHT / 2;
  private playerSprite!: Phaser.GameObjects.Image;
  private readonly enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private projectileGraphics!: Phaser.GameObjects.Graphics;
  private enemyHealthGraphics!: Phaser.GameObjects.Graphics;
  private reticleGraphics!: Phaser.GameObjects.Graphics;

  public constructor(callbacks?: ArenaSceneCallbacks) {
    super({ key: "ArenaScene" });
    this.callbacks = callbacks ?? null;
  }

  public setCallbacks(callbacks: ArenaSceneCallbacks): void {
    this.callbacks = callbacks;
  }

  public preload(): void {
    this.load.image("arena-background", `${ASSET_ROOT}/visuals/arena-background.webp`);
    this.load.image("menu-background", `${ASSET_ROOT}/visuals/menu-background.webp`);
    this.load.image("logo", `${ASSET_ROOT}/visuals/logo.webp`);
    this.load.image("player", `${ASSET_ROOT}/visuals/player.webp`);
    this.load.image("chaser", `${ASSET_ROOT}/visuals/enemies/chaser.webp`);
    this.load.image("striker", `${ASSET_ROOT}/visuals/enemies/striker.webp`);
    this.load.image("tank", `${ASSET_ROOT}/visuals/enemies/tank.webp`);
    this.load.image("heart", `${ASSET_ROOT}/visuals/ui/heart.webp`);
    this.load.image("score-icon", `${ASSET_ROOT}/visuals/ui/score.webp`);
    this.load.image("wave-icon", `${ASSET_ROOT}/visuals/ui/wave.webp`);
    this.load.spritesheet("explosion-atlas", `${ASSET_ROOT}/visuals/effects/explosion-atlas.webp`, {
      frameWidth: 64,
      frameHeight: 64,
    });
    this.load.spritesheet("impact-atlas", `${ASSET_ROOT}/visuals/effects/impact-atlas.webp`, {
      frameWidth: 64,
      frameHeight: 64,
    });
  }

  public create(): void {
    this.add.image(ARENA_WIDTH / 2, ARENA_HEIGHT / 2, "arena-background").setDepth(0);
    this.add.rectangle(ARENA_WIDTH / 2, ARENA_HEIGHT / 2, ARENA_WIDTH - 2 * ARENA_MARGIN, ARENA_HEIGHT - 2 * ARENA_MARGIN, 0x08111f, 0.16).setDepth(0);
    this.add.graphics().setDepth(1).lineStyle(1, 0x49dcb1, 0.1).strokeRect(ARENA_MARGIN, ARENA_MARGIN, ARENA_WIDTH - 2 * ARENA_MARGIN, ARENA_HEIGHT - 2 * ARENA_MARGIN);
    this.projectileGraphics = this.add.graphics().setDepth(2);
    this.enemyHealthGraphics = this.add.graphics().setDepth(4);
    this.playerSprite = this.add.image(ARENA_WIDTH / 2, ARENA_HEIGHT / 2, "player").setDepth(3).setDisplaySize(76, 76);
    this.reticleGraphics = this.add.graphics().setDepth(6);
    this.setupAnimations();
    this.setupInput();
    this.callbacks?.onReady(this);
    this.callbacks?.onSnapshot(this.simulation.getSnapshot());
  }

  public update(_time: number, delta: number): void {
    this.updatePointer();
    if (this.simulation.status === "running") {
      this.accumulator += Math.min(delta, 100);
      while (this.accumulator >= FIXED_STEP_MS) {
        this.simulation.step({
          up: this.isHeld("up"),
          down: this.isHeld("down"),
          left: this.isHeld("left"),
          right: this.isHeld("right"),
          fire: this.isHeld("fire") || this.pointerFire,
          aimX: this.aimX,
          aimY: this.aimY,
        });
        for (const event of this.simulation.drainEvents()) {
          this.handleSimulationEvent(event);
        }
        this.pointerFire = false;
        this.accumulator -= FIXED_STEP_MS;
      }
    } else {
      this.accumulator = 0;
      this.pointerFire = false;
    }
    this.renderSnapshot(this.simulation.getSnapshot());
  }

  public startGame(seed?: number): void {
    this.clearEnemies();
    this.simulation.start(seed);
    this.accumulator = 0;
    for (const event of this.simulation.drainEvents()) {
      this.handleSimulationEvent(event);
    }
    this.renderSnapshot(this.simulation.getSnapshot());
  }

  public pauseGame(): void {
    this.simulation.pause();
    this.renderSnapshot(this.simulation.getSnapshot());
  }

  public resumeGame(): void {
    this.simulation.resume();
    this.renderSnapshot(this.simulation.getSnapshot());
  }

  public togglePause(): void {
    this.simulation.togglePause();
    this.renderSnapshot(this.simulation.getSnapshot());
  }

  public getSnapshot(): SimulationSnapshot {
    return this.simulation.getSnapshot();
  }

  public getCompletedGame(): CompletedGame | null {
    return this.simulation.getSnapshot().completedGame;
  }

  private setupInput(): void {
    const keyboard = this.input.keyboard;
    if (keyboard) {
      this.keyGroups.up = [
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W),
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.UP),
      ];
      this.keyGroups.down = [
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S),
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.DOWN),
      ];
      this.keyGroups.left = [
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A),
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.LEFT),
      ];
      this.keyGroups.right = [
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D),
        keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.RIGHT),
      ];
      this.keyGroups.fire = [keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE)];
    }
    this.input.on("pointermove", (pointer: Phaser.Input.Pointer) => {
      this.aimX = pointer.x;
      this.aimY = pointer.y;
    });
    this.input.on("pointerdown", (pointer: Phaser.Input.Pointer) => {
      this.aimX = pointer.x;
      this.aimY = pointer.y;
      this.pointerFire = true;
    });
  }

  private updatePointer(): void {
    const pointer = this.input.activePointer;
    if (pointer) {
      this.aimX = pointer.x;
      this.aimY = pointer.y;
      if (pointer.isDown) {
        this.pointerFire = true;
      }
    }
  }

  private isHeld(key: KeyName): boolean {
    return this.keyGroups[key]?.some((candidate) => candidate.isDown) ?? false;
  }

  private setupAnimations(): void {
    this.anims.create({
      key: "enemy-defeat",
      frames: this.anims.generateFrameNumbers("explosion-atlas", { start: 0, end: 3 }),
      frameRate: 18,
      repeat: 0,
    });
    this.anims.create({
      key: "enemy-impact",
      frames: this.anims.generateFrameNumbers("impact-atlas", { start: 0, end: 3 }),
      frameRate: 24,
      repeat: 0,
    });
  }

  private handleSimulationEvent(event: SimulationEvent): void {
    this.callbacks?.onEvent(event);
    if (event.type === "enemyDefeated") {
      this.playEffect("enemy-defeat", event.x, event.y, 1.2);
    } else if (event.type === "enemyHit") {
      this.playEffect("enemy-impact", event.x, event.y, 0.7);
    }
  }

  private playEffect(animationKey: "enemy-defeat" | "enemy-impact", x: number, y: number, scale: number): void {
    const effect = this.add.sprite(x, y, animationKey === "enemy-defeat" ? "explosion-atlas" : "impact-atlas").setDepth(5).setScale(scale);
    effect.play(animationKey);
    effect.once("animationcomplete", () => effect.destroy());
  }

  private renderSnapshot(snapshot: SimulationSnapshot): void {
    this.playerSprite.setPosition(snapshot.player.x, snapshot.player.y);
    const flashing = snapshot.player.invulnerableUntilTick > snapshot.tick && snapshot.tick % 8 < 4;
    this.playerSprite.setAlpha(flashing ? 0.38 : 1);

    const activeEnemyIds = new Set<number>();
    this.enemyHealthGraphics.clear();
    for (const enemy of snapshot.enemies) {
      activeEnemyIds.add(enemy.id);
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.add.image(enemy.x, enemy.y, enemy.kind).setDepth(3);
        this.enemySprites.set(enemy.id, sprite);
      }
      sprite.setTexture(this.textureForEnemy(enemy.kind));
      const displaySize = enemy.radius * 2.7;
      sprite.setDisplaySize(displaySize, displaySize).setPosition(enemy.x, enemy.y);
      sprite.setAlpha(0.92);
      if (enemy.health < enemy.maxHealth) {
        const width = enemy.radius * 2.4;
        const progress = enemy.health / enemy.maxHealth;
        this.enemyHealthGraphics.fillStyle(0x08111f, 0.8).fillRect(enemy.x - width / 2, enemy.y - enemy.radius - 12, width, 5);
        this.enemyHealthGraphics.fillStyle(enemy.kind === "tank" ? 0xf6c453 : 0xff4f78, 1).fillRect(enemy.x - width / 2, enemy.y - enemy.radius - 12, width * progress, 5);
      }
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!activeEnemyIds.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
      }
    }

    this.projectileGraphics.clear();
    for (const projectile of snapshot.projectiles) {
      this.projectileGraphics.fillStyle(0xf6c453, 0.18).fillCircle(projectile.x, projectile.y, projectile.radius * 2.2);
      this.projectileGraphics.fillStyle(0xf6c453, 1).fillCircle(projectile.x, projectile.y, projectile.radius);
    }

    this.reticleGraphics.clear();
    this.reticleGraphics.lineStyle(2, 0x49dcb1, 0.7);
    this.reticleGraphics.strokeCircle(this.aimX, this.aimY, 11);
    this.reticleGraphics.lineBetween(this.aimX - 17, this.aimY, this.aimX - 5, this.aimY);
    this.reticleGraphics.lineBetween(this.aimX + 5, this.aimY, this.aimX + 17, this.aimY);
    this.reticleGraphics.lineBetween(this.aimX, this.aimY - 17, this.aimX, this.aimY - 5);
    this.reticleGraphics.lineBetween(this.aimX, this.aimY + 5, this.aimX, this.aimY + 17);
    this.callbacks?.onSnapshot(snapshot);
  }

  private textureForEnemy(kind: EnemyKind): string {
    return kind;
  }

  private clearEnemies(): void {
    for (const sprite of this.enemySprites.values()) {
      sprite.destroy();
    }
    this.enemySprites.clear();
  }
}
