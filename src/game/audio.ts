export type EffectName = "shoot" | "enemyHit" | "enemyDefeat" | "playerHit" | "waveStart" | "gameOver";

export interface AudioSettings {
  muted: boolean;
  musicVolume: number;
  effectsVolume: number;
}

const STORAGE_KEYS = {
  muted: "vectorSiege.muted",
  musicVolume: "vectorSiege.musicVolume",
  effectsVolume: "vectorSiege.effectsVolume",
} as const;

const AUDIO_PATHS: Record<EffectName, string> = {
  shoot: "/benchmark-assets/vector-siege/audio/shoot.wav",
  enemyHit: "/benchmark-assets/vector-siege/audio/enemy-hit.wav",
  enemyDefeat: "/benchmark-assets/vector-siege/audio/enemy-defeat.wav",
  playerHit: "/benchmark-assets/vector-siege/audio/player-hit.wav",
  waveStart: "/benchmark-assets/vector-siege/audio/wave-start.wav",
  gameOver: "/benchmark-assets/vector-siege/audio/game-over.wav",
};

const MENU_MUSIC_PATH = "/benchmark-assets/vector-siege/audio/menu-theme.mp3";
const GAMEPLAY_MUSIC_PATH = "/benchmark-assets/vector-siege/audio/gameplay-loop.mp3";

export class AudioManager {
  private settings: AudioSettings;
  private menuMusic: HTMLAudioElement | null = null;
  private gameplayMusic: HTMLAudioElement | null = null;
  private unlocked = false;

  public constructor() {
    this.settings = {
      muted: readBoolean(STORAGE_KEYS.muted, false),
      musicVolume: readNumber(STORAGE_KEYS.musicVolume, 0.16),
      effectsVolume: readNumber(STORAGE_KEYS.effectsVolume, 0.22),
    };
  }

  public async unlock(): Promise<void> {
    if (typeof Audio === "undefined") {
      console.warn("Vector Siege audio is unavailable in this runtime.");
      return;
    }
    if (!this.menuMusic) {
      this.menuMusic = createTrack(MENU_MUSIC_PATH, true);
      this.gameplayMusic = createTrack(GAMEPLAY_MUSIC_PATH, true);
    }
    this.unlocked = true;
    await this.playTrack(this.menuMusic);
  }

  public async playMenuMusic(): Promise<void> {
    if (!this.unlocked || !this.menuMusic) {
      return;
    }
    this.stopTrack(this.gameplayMusic);
    await this.playTrack(this.menuMusic);
  }

  public async playGameplayMusic(): Promise<void> {
    if (!this.unlocked || !this.gameplayMusic) {
      return;
    }
    this.stopTrack(this.menuMusic);
    await this.playTrack(this.gameplayMusic);
  }

  public stopAll(): void {
    this.stopTrack(this.menuMusic);
    this.stopTrack(this.gameplayMusic);
  }

  public pauseGameplayMusic(): void {
    this.gameplayMusic?.pause();
  }

  public async resumeGameplayMusic(): Promise<void> {
    if (!this.unlocked || !this.gameplayMusic) {
      return;
    }
    await this.playTrack(this.gameplayMusic);
  }

  public playEffect(name: EffectName): void {
    if (!this.unlocked || typeof Audio === "undefined") {
      return;
    }
    const effect = createTrack(AUDIO_PATHS[name], false);
    effect.volume = this.settings.effectsVolume;
    effect.muted = this.settings.muted;
    void effect.play().catch((error: unknown) => {
      console.warn(`Vector Siege effect '${name}' could not play.`, error);
    });
  }

  public toggleMute(): boolean {
    this.setMuted(!this.settings.muted);
    return this.settings.muted;
  }

  public setMuted(muted: boolean): void {
    this.settings.muted = muted;
    this.applyTrackSettings();
    persist(STORAGE_KEYS.muted, String(muted));
  }

  public setMusicVolume(volume: number): void {
    this.settings.musicVolume = clampVolume(volume);
    this.applyTrackSettings();
    persist(STORAGE_KEYS.musicVolume, String(this.settings.musicVolume));
  }

  public setEffectsVolume(volume: number): void {
    this.settings.effectsVolume = clampVolume(volume);
    persist(STORAGE_KEYS.effectsVolume, String(this.settings.effectsVolume));
  }

  public getSettings(): AudioSettings {
    return { ...this.settings };
  }

  private async playTrack(track: HTMLAudioElement): Promise<void> {
    track.loop = true;
    track.volume = this.settings.musicVolume;
    track.muted = this.settings.muted;
    try {
      await track.play();
    } catch (error: unknown) {
      console.warn("Vector Siege music could not start; audio remains unlocked for the next gesture.", error);
    }
  }

  private stopTrack(track: HTMLAudioElement | null): void {
    if (!track) {
      return;
    }
    track.pause();
    track.currentTime = 0;
  }

  private applyTrackSettings(): void {
    for (const track of [this.menuMusic, this.gameplayMusic]) {
      if (track) {
        track.volume = this.settings.musicVolume;
        track.muted = this.settings.muted;
      }
    }
  }
}

function createTrack(source: string, loop: boolean): HTMLAudioElement {
  const track = new Audio(source);
  track.preload = "auto";
  track.loop = loop;
  return track;
}

function clampVolume(volume: number): number {
  return Math.max(0, Math.min(1, Number.isFinite(volume) ? volume : 0));
}

function readBoolean(key: string, fallback: boolean): boolean {
  if (typeof window === "undefined") {
    return fallback;
  }
  try {
    return window.localStorage.getItem(key) === "true";
  } catch (error: unknown) {
    console.warn(`Vector Siege could not read '${key}' from local storage.`, error);
    return fallback;
  }
}

function readNumber(key: string, fallback: number): number {
  if (typeof window === "undefined") {
    return fallback;
  }
  try {
    const storedValue = window.localStorage.getItem(key);
    if (storedValue === null) {
      return fallback;
    }
    const value = Number(storedValue);
    return Number.isFinite(value) ? clampVolume(value) : fallback;
  } catch (error: unknown) {
    console.warn(`Vector Siege could not read '${key}' from local storage.`, error);
    return fallback;
  }
}

function persist(key: string, value: string): void {
  if (typeof window === "undefined") {
    return;
  }
  try {
    window.localStorage.setItem(key, value);
  } catch (error: unknown) {
    console.warn(`Vector Siege could not persist '${key}' to local storage.`, error);
  }
}
