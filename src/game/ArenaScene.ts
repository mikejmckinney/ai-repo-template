import Phaser from "phaser";

import {
  ARENA_BOUNDS,
  DEFAULT_SEED,
  FIXED_STEP_MS,
  SimulationEvent,
  SimulationState,
  createSimulation,
  pauseSimulation,
  restartSimulation,
  resumeSimulation,
  snapshotSimulation,
  startSimulation,
  stepSimulation,
} from "../shared-simulation/simulation";

const WIDTH = 1280;
const HEIGHT = 720;
const ASSET_ROOT = "/benchmark-assets/vector-siege";

type MusicKey = "menu-theme" | "gameplay-loop";
type KeyMap = {
  up: Phaser.Input.Keyboard.Key;
  down: Phaser.Input.Keyboard.Key;
  left: Phaser.Input.Keyboard.Key;
  right: Phaser.Input.Keyboard.Key;
  w: Phaser.Input.Keyboard.Key;
  s: Phaser.Input.Keyboard.Key;
  a: Phaser.Input.Keyboard.Key;
  d: Phaser.Input.Keyboard.Key;
  space: Phaser.Input.Keyboard.Key;
  escape: Phaser.Input.Keyboard.Key;
};

interface AudioSettings {
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
}

interface EffectInstance {
  sprite: Phaser.GameObjects.Sprite;
  ttl: number;
  maxTtl: number;
}

interface VectorSiegeBridge {
  getState: () => SimulationState;
  start: (seed?: string) => void;
  pause: () => void;
  resume: () => void;
  restart: (seed?: string) => void;
  toggleMute: () => void;
}

declare global {
  interface Window {
    __VECTOR_SIEGE__?: VectorSiegeBridge;
  }
}

function byId<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);
  if (!element) throw new Error(`Missing Vector Siege UI element: ${id}`);
  return element as T;
}

function pad(value: number, length: number): string {
  return String(value).padStart(length, "0");
}

function safeNumber(value: string | null, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(0, Math.min(1, parsed)) : fallback;
}

function readAudioSettings(): AudioSettings {
  try {
    return {
      musicVolume: safeNumber(localStorage.getItem("vectorSiege.musicVolume"), 0.42),
      effectsVolume: safeNumber(localStorage.getItem("vectorSiege.effectsVolume"), 0.7),
      muted: localStorage.getItem("vectorSiege.muted") === "true",
    };
  } catch {
    return { musicVolume: 0.42, effectsVolume: 0.7, muted: false };
  }
}

function writeSetting(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Storage is an enhancement; a locked-down browser should not break play.
  }
}

export default class ArenaScene extends Phaser.Scene {
  private state: SimulationState = createSimulation(DEFAULT_SEED);
  private accumulator = 0;
  private pointerShotQueued = false;
  private pointerAim = { x: 641, y: 405 };
  private keys!: KeyMap;
  private settings = readAudioSettings();
  private music: Phaser.Sound.BaseSound | null = null;
  private currentMusicKey: MusicKey | null = null;
  private pendingMusicKey: MusicKey | null = null;
  private audioUnlocked = false;

  private background!: Phaser.GameObjects.Image;
  private arenaDecor!: Phaser.GameObjects.Graphics;
  private projectileGraphics!: Phaser.GameObjects.Graphics;
  private playerGlow!: Phaser.GameObjects.Graphics;
  private aimGraphics!: Phaser.GameObjects.Graphics;
  private enemyBars!: Phaser.GameObjects.Graphics;
  private logoSprite!: Phaser.GameObjects.Image;
  private playerSprite!: Phaser.GameObjects.Image;
  private enemySprites = new Map<number, Phaser.GameObjects.Image>();
  private effects: EffectInstance[] = [];

  private startPanel!: HTMLElement;
  private hud!: HTMLElement;
  private pausePanel!: HTMLElement;
  private gameOverPanel!: HTMLElement;
  private gameStateLabel!: HTMLElement;
  private hudScore!: HTMLElement;
  private hudWave!: HTMLElement;
  private hudHealth!: HTMLElement;
  private hudStatus!: HTMLElement;
  private finalScore!: HTMLElement;
  private finalWave!: HTMLElement;
  private finalTick!: HTMLElement;
  private audioBadge!: HTMLElement;
  private musicSlider!: HTMLInputElement;
  private effectsSlider!: HTMLInputElement;
  private seedInput!: HTMLInputElement;
  private muteButtons: HTMLButtonElement[] = [];

  constructor() {
    super("ArenaScene");
  }

  preload(): void {
    this.load.image("menu-bg", `${ASSET_ROOT}/visuals/menu-background.webp`);
    this.load.image("arena-bg", `${ASSET_ROOT}/visuals/arena-background.webp`);
    this.load.image("logo", `${ASSET_ROOT}/visuals/logo.webp`);
    this.load.image("player", `${ASSET_ROOT}/visuals/player.webp`);
    this.load.image("chaser", `${ASSET_ROOT}/visuals/enemies/chaser.webp`);
    this.load.image("striker", `${ASSET_ROOT}/visuals/enemies/striker.webp`);
    this.load.image("tank", `${ASSET_ROOT}/visuals/enemies/tank.webp`);
    this.load.image("heart", `${ASSET_ROOT}/visuals/ui/heart.webp`);
    this.load.image("score-icon", `${ASSET_ROOT}/visuals/ui/score.webp`);
    this.load.image("wave-icon", `${ASSET_ROOT}/visuals/ui/wave.webp`);
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
    this.load.audio("enemy-defeat", `${ASSET_ROOT}/audio/enemy-defeat.wav`);
    this.load.audio("player-hit", `${ASSET_ROOT}/audio/player-hit.wav`);
    this.load.audio("wave-start", `${ASSET_ROOT}/audio/wave-start.wav`);
    this.load.audio("game-over", `${ASSET_ROOT}/audio/game-over.wav`);
  }

  create(): void {
    this.background = this.add.image(WIDTH / 2, HEIGHT / 2, "menu-bg").setDisplaySize(WIDTH, HEIGHT).setDepth(0);
    this.arenaDecor = this.add.graphics().setDepth(1);
    this.projectileGraphics = this.add.graphics().setDepth(3);
    this.playerGlow = this.add.graphics().setDepth(3);
    this.enemyBars = this.add.graphics().setDepth(5);
    this.aimGraphics = this.add.graphics().setDepth(6);
    this.logoSprite = this.add.image(WIDTH / 2, 118, "logo").setDisplaySize(420, 105).setDepth(2);
    this.playerSprite = this.add.image(0, 0, "player").setDisplaySize(58, 58).setDepth(4).setVisible(false);

    const keyboard = this.input.keyboard;
    if (!keyboard) throw new Error("Vector Siege requires keyboard input");
    this.keys = {
      up: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.UP),
      down: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.DOWN),
      left: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.LEFT),
      right: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.RIGHT),
      w: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W),
      s: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S),
      a: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A),
      d: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D),
      space: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE),
      escape: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC),
    };
    keyboard.addCapture(["SPACE", "UP", "DOWN", "LEFT", "RIGHT", "ESC"]);
    this.input.on("pointerdown", this.handlePointerDown, this);
    this.input.on("pointermove", this.handlePointerMove, this);
    this.sound.on("unlocked", this.handleAudioUnlocked, this);

    this.bindUi();
    this.installBridge();
    this.applyAudioSettings();
    this.switchMusic("menu-theme");
    this.updateUi();
    this.renderFrame();
  }

  update(_time: number, delta: number): void {
    if (Phaser.Input.Keyboard.JustDown(this.keys.escape)) {
      if (this.state.status === "running") this.pauseGame();
      else if (this.state.status === "paused") this.resumeGame();
    }
    if (this.state.status === "menu" && Phaser.Input.Keyboard.JustDown(this.keys.space)) {
      this.startGame(this.seedInput.value);
    }

    if (this.state.status === "running") {
      this.accumulator += Math.min(delta, 100);
      let steps = 0;
      while (this.accumulator >= FIXED_STEP_MS && steps < 8) {
        const events = stepSimulation(this.state, this.captureInput());
        this.handleSimulationEvents(events);
        this.accumulator -= FIXED_STEP_MS;
        steps += 1;
      }
    }

    this.updateEffects();
    this.updateUi();
    this.renderFrame();
  }

  private bindUi(): void {
    this.startPanel = byId("start-panel");
    this.hud = byId("hud");
    this.pausePanel = byId("pause-panel");
    this.gameOverPanel = byId("game-over-panel");
    this.gameStateLabel = byId("game-state");
    this.hudScore = byId("hud-score");
    this.hudWave = byId("hud-wave");
    this.hudHealth = byId("hud-health");
    this.hudStatus = byId("hud-status");
    this.finalScore = byId("final-score");
    this.finalWave = byId("final-wave");
    this.finalTick = byId("final-tick");
    this.audioBadge = byId("audio-badge");
    this.musicSlider = byId<HTMLInputElement>("music-volume");
    this.effectsSlider = byId<HTMLInputElement>("effects-volume");
    this.seedInput = byId<HTMLInputElement>("seed-input");
    this.musicSlider.value = String(this.settings.musicVolume);
    this.effectsSlider.value = String(this.settings.effectsVolume);
    this.muteButtons = [byId<HTMLButtonElement>("menu-mute-button"), byId<HTMLButtonElement>("hud-mute-button")];

    byId<HTMLButtonElement>("start-button").addEventListener("click", () => this.startGame(this.seedInput.value));
    byId<HTMLButtonElement>("pause-button").addEventListener("click", () => this.togglePause());
    byId<HTMLButtonElement>("resume-button").addEventListener("click", () => this.resumeGame());
    byId<HTMLButtonElement>("restart-button").addEventListener("click", () => this.restartGame());
    byId<HTMLButtonElement>("return-menu-button").addEventListener("click", () => this.returnToMenu());
    for (const button of this.muteButtons) button.addEventListener("click", () => this.toggleMute());

    this.musicSlider.addEventListener("input", () => {
      this.settings.musicVolume = Number(this.musicSlider.value);
      writeSetting("vectorSiege.musicVolume", String(this.settings.musicVolume));
      if (this.music) {
        (this.music as unknown as { setVolume: (value: number) => void }).setVolume(this.settings.musicVolume);
      }
    });
    this.effectsSlider.addEventListener("input", () => {
      this.settings.effectsVolume = Number(this.effectsSlider.value);
      writeSetting("vectorSiege.effectsVolume", String(this.settings.effectsVolume));
    });
  }

  private installBridge(): void {
    window.__VECTOR_SIEGE__ = {
      getState: () => snapshotSimulation(this.state),
      start: (seed?: string) => this.startGame(seed ?? this.seedInput.value),
      pause: () => this.pauseGame(),
      resume: () => this.resumeGame(),
      restart: (seed?: string) => this.restartGame(seed),
      toggleMute: () => this.toggleMute(),
    };
  }

  private applyAudioSettings(): void {
    this.sound.setMute(this.settings.muted);
    this.updateMuteButtons();
  }

  private handleAudioUnlocked(): void {
    this.audioUnlocked = true;
    this.audioBadge.textContent = "◉ AUDIO LINKED // LIVE";
    this.audioBadge.classList.add("unlocked");
    if (this.pendingMusicKey) {
      const key = this.pendingMusicKey;
      this.pendingMusicKey = null;
      this.switchMusic(key);
    }
  }

  private switchMusic(key: MusicKey): void {
    if (this.currentMusicKey === key && this.music) {
      if (!this.music.isPlaying && !this.sound.locked) this.music.play();
      return;
    }
    this.music?.stop();
    this.music?.destroy();
    this.music = null;
    this.currentMusicKey = key;
    try {
      this.music = this.sound.add(key, { loop: true, volume: this.settings.musicVolume });
      if (this.sound.locked) {
        this.pendingMusicKey = key;
      } else {
        this.music.play();
      }
    } catch {
      this.music = null;
    }
  }

  private playSfx(key: string): void {
    if (this.settings.muted || this.settings.effectsVolume <= 0) return;
    try {
      this.sound.play(key, { volume: this.settings.effectsVolume });
    } catch {
      // Placeholder audio should never make the simulation fail.
    }
  }

  private toggleMute(): void {
    this.settings.muted = !this.settings.muted;
    writeSetting("vectorSiege.muted", String(this.settings.muted));
    this.sound.setMute(this.settings.muted);
    this.updateMuteButtons();
  }

  private updateMuteButtons(): void {
    const label = this.settings.muted ? "SOUND MUTED" : "SOUND ON";
    for (const button of this.muteButtons) {
      button.textContent = label;
      button.setAttribute("aria-pressed", String(this.settings.muted));
    }
  }

  private startGame(seed: string): void {
    const normalizedSeed = seed.trim() || DEFAULT_SEED;
    this.seedInput.value = normalizedSeed;
    this.state = startSimulation(normalizedSeed);
    this.accumulator = 0;
    this.pointerShotQueued = false;
    this.clearEffects();
    this.clearEnemySprites();
    this.switchMusic("gameplay-loop");
    this.sound.resumeAll();
    this.applyAudioSettings();
    (document.activeElement as HTMLElement | null)?.blur();
    this.updateUi();
  }

  private restartGame(seed?: string): void {
    const normalizedSeed = (seed ?? this.state.seed).trim() || DEFAULT_SEED;
    this.state = restartSimulation(this.state, normalizedSeed);
    this.accumulator = 0;
    this.pointerShotQueued = false;
    this.clearEffects();
    this.clearEnemySprites();
    this.switchMusic("gameplay-loop");
    this.sound.resumeAll();
    this.applyAudioSettings();
    this.updateUi();
  }

  private returnToMenu(): void {
    this.state = createSimulation(this.state.seed);
    this.accumulator = 0;
    this.pointerShotQueued = false;
    this.clearEffects();
    this.clearEnemySprites();
    this.sound.stopAll();
    this.switchMusic("menu-theme");
    this.updateUi();
  }

  private pauseGame(): void {
    if (pauseSimulation(this.state)) {
      this.sound.pauseAll();
      this.updateUi();
    }
  }

  private resumeGame(): void {
    if (resumeSimulation(this.state)) {
      this.sound.resumeAll();
      this.updateUi();
    }
  }

  private togglePause(): void {
    if (this.state.status === "running") this.pauseGame();
    else if (this.state.status === "paused") this.resumeGame();
  }

  private handlePointerDown(pointer: Phaser.Input.Pointer): void {
    this.pointerAim = { x: pointer.worldX, y: pointer.worldY };
    if (this.state.status === "menu") {
      this.startGame(this.seedInput.value);
      return;
    }
    if (this.state.status === "running") this.pointerShotQueued = true;
  }

  private handlePointerMove(pointer: Phaser.Input.Pointer): void {
    this.pointerAim = { x: pointer.worldX, y: pointer.worldY };
  }

  private captureInput(): {
    up: boolean;
    down: boolean;
    left: boolean;
    right: boolean;
    fire: boolean;
    aimX: number;
    aimY: number;
  } {
    const pointer = this.input.activePointer;
    const aimX = Number.isFinite(pointer.worldX) ? pointer.worldX : this.pointerAim.x;
    const aimY = Number.isFinite(pointer.worldY) ? pointer.worldY : this.pointerAim.y;
    const input = {
      up: this.keys.up.isDown || this.keys.w.isDown,
      down: this.keys.down.isDown || this.keys.s.isDown,
      left: this.keys.left.isDown || this.keys.a.isDown,
      right: this.keys.right.isDown || this.keys.d.isDown,
      fire: this.keys.space.isDown || pointer.isDown || this.pointerShotQueued,
      aimX,
      aimY,
    };
    this.pointerShotQueued = false;
    return input;
  }

  private handleSimulationEvents(events: SimulationEvent[]): void {
    for (const event of events) {
      if (event.type === "shot") {
        this.playSfx("shoot");
      } else if (event.type === "enemy-hit") {
        this.playSfx("enemy-hit");
        this.spawnEffect("impact", event.x, event.y, 0.78, 16);
      } else if (event.type === "enemy-defeated") {
        this.playSfx("enemy-defeat");
        this.spawnEffect("explosion", event.x, event.y, event.kind === "tank" ? 1.3 : 1, 24);
      } else if (event.type === "player-hit") {
        this.playSfx("player-hit");
        this.cameras.main.flash(120, 255, 79, 120);
      } else if (event.type === "wave-start") {
        if (event.wave > 1) this.playSfx("wave-start");
      } else if (event.type === "game-over") {
        this.recordCompletion(event.completion);
        this.sound.stopAll();
        this.playSfx("game-over");
      }
    }
  }

  private recordCompletion(completion: NonNullable<SimulationState["completion"]>): void {
    try {
      const previousHighScore = Number(localStorage.getItem("vectorSiege.highScore") ?? 0);
      if (completion.score > previousHighScore) writeSetting("vectorSiege.highScore", String(completion.score));
      writeSetting("vectorSiege.lastCompletion", JSON.stringify(completion));
    } catch {
      // Completion remains available through the simulation bridge.
    }
  }

  private spawnEffect(texture: "impact" | "explosion", x: number, y: number, scale: number, ttl: number): void {
    const sprite = this.add.sprite(x, y, texture, "frame-0").setDisplaySize(64 * scale, 64 * scale).setDepth(7);
    this.effects.push({ sprite, ttl, maxTtl: ttl });
  }

  private updateEffects(): void {
    for (let index = this.effects.length - 1; index >= 0; index -= 1) {
      const effect = this.effects[index];
      effect.ttl -= 1;
      const frame = Math.min(3, Math.floor(((effect.maxTtl - effect.ttl) / effect.maxTtl) * 4));
      effect.sprite.setFrame(`frame-${frame}`);
      effect.sprite.setAlpha(Math.max(0, effect.ttl / effect.maxTtl));
      if (effect.ttl <= 0) {
        effect.sprite.destroy();
        this.effects.splice(index, 1);
      }
    }
  }

  private clearEffects(): void {
    for (const effect of this.effects) effect.sprite.destroy();
    this.effects = [];
  }

  private clearEnemySprites(): void {
    for (const sprite of this.enemySprites.values()) sprite.destroy();
    this.enemySprites.clear();
  }

  private updateUi(): void {
    const status = this.state.status;
    this.startPanel.hidden = status !== "menu";
    this.hud.hidden = status === "menu" || status === "game-over";
    this.pausePanel.hidden = status !== "paused";
    this.gameOverPanel.hidden = status !== "game-over";
    this.gameStateLabel.textContent = status.toUpperCase();
    document.body.dataset.vectorSiegeState = status;

    this.hudScore.textContent = pad(this.state.score, 6);
    this.hudWave.textContent = pad(this.state.wave, 2);
    const fullHealth = "♥".repeat(this.state.health);
    const emptyHealth = "♡".repeat(Math.max(0, this.state.maxHealth - this.state.health));
    this.hudHealth.textContent = fullHealth + emptyHealth;
    this.hudStatus.textContent = status === "paused" ? "PAUSED" : "LIVE";

    const completion = this.state.completion;
    this.finalScore.textContent = pad(completion?.score ?? this.state.score, 6);
    this.finalWave.textContent = pad(completion?.wave ?? this.state.wave, 2);
    this.finalTick.textContent = pad(completion?.finalTick ?? this.state.tick, 6);
    this.updateMuteButtons();
  }

  private renderFrame(): void {
    if (this.state.status === "menu") this.renderMenu();
    else this.renderGameplay();
  }

  private renderMenu(): void {
    this.background.setTexture("menu-bg").setDisplaySize(WIDTH, HEIGHT).setVisible(true);
    this.arenaDecor.clear();
    this.projectileGraphics.clear();
    this.playerGlow.clear();
    this.aimGraphics.clear();
    this.enemyBars.clear();
    this.playerSprite.setVisible(false);
    this.logoSprite.setVisible(true);
    for (const sprite of this.enemySprites.values()) sprite.setVisible(false);
  }

  private renderGameplay(): void {
    this.background.setTexture("arena-bg").setDisplaySize(WIDTH, HEIGHT).setVisible(true);
    this.logoSprite.setVisible(false);
    this.drawArenaDecor();
    this.drawProjectiles();
    this.drawPlayer();
    this.drawEnemies();
    this.drawAim();
  }

  private drawArenaDecor(): void {
    this.arenaDecor.clear();
    this.arenaDecor.fillStyle(0x08111f, 0.2);
    this.arenaDecor.fillRect(0, 0, WIDTH, HEIGHT);
    this.arenaDecor.lineStyle(1, 0x61728b, 0.12);
    for (let x = ARENA_BOUNDS.left; x <= ARENA_BOUNDS.right; x += 64) this.arenaDecor.lineBetween(x, ARENA_BOUNDS.top, x, ARENA_BOUNDS.bottom);
    for (let y = ARENA_BOUNDS.top; y <= ARENA_BOUNDS.bottom; y += 64) this.arenaDecor.lineBetween(ARENA_BOUNDS.left, y, ARENA_BOUNDS.right, y);
    this.arenaDecor.lineStyle(2, 0x49dcb1, 0.48);
    this.arenaDecor.strokeRect(ARENA_BOUNDS.left, ARENA_BOUNDS.top, ARENA_BOUNDS.right - ARENA_BOUNDS.left, ARENA_BOUNDS.bottom - ARENA_BOUNDS.top);
    this.arenaDecor.lineStyle(1, 0x49dcb1, 0.25);
    this.arenaDecor.lineBetween(WIDTH / 2 - 12, ARENA_BOUNDS.top + 18, WIDTH / 2 + 12, ARENA_BOUNDS.top + 18);
    this.arenaDecor.lineBetween(WIDTH / 2 - 12, ARENA_BOUNDS.bottom - 18, WIDTH / 2 + 12, ARENA_BOUNDS.bottom - 18);
  }

  private drawProjectiles(): void {
    this.projectileGraphics.clear();
    for (const projectile of this.state.projectiles) {
      const tailX = projectile.x - projectile.dx * 20;
      const tailY = projectile.y - projectile.dy * 20;
      this.projectileGraphics.lineStyle(4, 0x49dcb1, 0.18);
      this.projectileGraphics.lineBetween(tailX, tailY, projectile.x, projectile.y);
      this.projectileGraphics.fillStyle(0xeffcff, 1);
      this.projectileGraphics.fillCircle(projectile.x, projectile.y, projectile.radius);
      this.projectileGraphics.fillStyle(0x49dcb1, 1);
      this.projectileGraphics.fillCircle(projectile.x, projectile.y, 3);
    }
  }

  private drawPlayer(): void {
    const player = this.state.player;
    this.playerGlow.clear();
    this.playerGlow.fillStyle(0x49dcb1, 0.12);
    this.playerGlow.fillCircle(player.x, player.y, 39);
    this.playerGlow.lineStyle(1, 0x49dcb1, 0.5);
    this.playerGlow.strokeCircle(player.x, player.y, 33 + Math.sin(this.state.tick * 0.07) * 2);
    this.playerSprite.setVisible(true).setPosition(player.x, player.y);
    this.playerSprite.setAlpha(this.state.invulnerableTicks > 0 && this.state.tick % 8 < 4 ? 0.3 : 1);
    const aimAngle = Math.atan2(this.pointerAim.y - player.y, this.pointerAim.x - player.x);
    this.playerSprite.setRotation(aimAngle + Math.PI / 4);
  }

  private drawEnemies(): void {
    const active = new Set<number>();
    this.enemyBars.clear();
    for (const enemy of this.state.enemies) {
      active.add(enemy.id);
      let sprite = this.enemySprites.get(enemy.id);
      if (!sprite) {
        sprite = this.add.image(enemy.x, enemy.y, enemy.kind).setDepth(4);
        this.enemySprites.set(enemy.id, sprite);
      }
      const size = enemy.kind === "tank" ? 72 : enemy.kind === "striker" ? 60 : 56;
      sprite.setDisplaySize(size, size).setVisible(true).setPosition(enemy.x, enemy.y);
      sprite.setAlpha(enemy.flashTicks > 0 && enemy.flashTicks % 2 === 0 ? 1 : 0.92);
      if (enemy.flashTicks > 0) sprite.setTint(0xffffff);
      else sprite.clearTint();

      const barWidth = enemy.kind === "tank" ? 64 : 52;
      const barX = enemy.x - barWidth / 2;
      const barY = enemy.y - enemy.radius - 13;
      this.enemyBars.fillStyle(0x08111f, 0.85);
      this.enemyBars.fillRect(barX, barY, barWidth, 5);
      const ratio = Math.max(0, enemy.health / enemy.maxHealth);
      const color = enemy.kind === "tank" ? 0xf6c453 : enemy.kind === "striker" ? 0x61728b : 0xff4f78;
      this.enemyBars.fillStyle(color, 0.95);
      this.enemyBars.fillRect(barX, barY, barWidth * ratio, 5);
    }
    for (const [id, sprite] of this.enemySprites) {
      if (!active.has(id)) {
        sprite.destroy();
        this.enemySprites.delete(id);
      }
    }
  }

  private drawAim(): void {
    this.aimGraphics.clear();
    const pointer = this.input.activePointer;
    const x = Number.isFinite(pointer.worldX) ? pointer.worldX : this.pointerAim.x;
    const y = Number.isFinite(pointer.worldY) ? pointer.worldY : this.pointerAim.y;
    if (this.state.status === "paused" || this.state.status === "game-over") return;
    this.aimGraphics.lineStyle(1, 0xeffcff, 0.62);
    this.aimGraphics.strokeCircle(x, y, 9);
    this.aimGraphics.lineBetween(x - 15, y, x - 5, y);
    this.aimGraphics.lineBetween(x + 5, y, x + 15, y);
    this.aimGraphics.lineBetween(x, y - 15, x, y - 5);
    this.aimGraphics.lineBetween(x, y + 5, x, y + 15);
  }
}
