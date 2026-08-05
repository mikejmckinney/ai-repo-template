import { clampVolume, loadAudioSettings, saveAudioSettings, type AudioSettings } from "./persistence";

interface SoundInstance {
  isPlaying?: boolean;
  play(): boolean;
  stop(): void;
  setVolume?(volume: number): SoundInstance;
}

export interface SoundManagerLike {
  locked: boolean;
  mute: boolean;
  add(key: string, config?: { loop?: boolean; volume?: number }): SoundInstance;
  play(key: string, config?: { volume?: number }): boolean;
  pauseAll(): void;
  resumeAll(): void;
  setMute(value: boolean): void;
  once(event: string, callback: () => void): void;
}

export type MusicMode = "menu" | "gameplay";

const MUSIC_KEYS: Record<MusicMode, string> = {
  menu: "menu-music",
  gameplay: "gameplay-music",
};

export class AudioController {
  private readonly manager: SoundManagerLike;
  private settings: AudioSettings;
  private music: SoundInstance | null = null;
  private musicMode: MusicMode | null = null;

  public constructor(manager: SoundManagerLike) {
    this.manager = manager;
    this.settings = loadAudioSettings();
    this.manager.setMute(this.settings.muted);
  }

  public get muted(): boolean {
    return this.settings.muted;
  }

  public get musicVolume(): number {
    return this.settings.musicVolume;
  }

  public get effectsVolume(): number {
    return this.settings.effectsVolume;
  }

  public playMusic(mode: MusicMode): void {
    if (this.musicMode === mode && this.music?.isPlaying) return;

    this.stopMusic();
    this.musicMode = mode;
    this.music = this.manager.add(MUSIC_KEYS[mode], {
      loop: true,
      volume: this.settings.musicVolume,
    });

    const play = (): void => {
      this.music?.play();
    };

    if (this.manager.locked) {
      this.manager.once("unlocked", play);
    } else {
      play();
    }
  }

  public playEffect(key: string): void {
    if (this.settings.muted || this.settings.effectsVolume <= 0) return;
    this.manager.play(key, { volume: this.settings.effectsVolume });
  }

  public pause(): void {
    this.manager.pauseAll();
  }

  public resume(): void {
    this.manager.resumeAll();
  }

  public stopMusic(): void {
    this.music?.stop();
    this.music = null;
    this.musicMode = null;
  }

  public toggleMute(): boolean {
    this.setMuted(!this.settings.muted);
    return this.settings.muted;
  }

  public setMuted(muted: boolean): void {
    this.settings.muted = muted;
    this.manager.setMute(muted);
    this.persist();
  }

  public setMusicVolume(volume: number): void {
    this.settings.musicVolume = clampVolume(volume);
    this.music?.setVolume?.(this.settings.musicVolume);
    this.persist();
  }

  public setEffectsVolume(volume: number): void {
    this.settings.effectsVolume = clampVolume(volume);
    this.persist();
  }

  public getSettings(): AudioSettings {
    return { ...this.settings };
  }

  private persist(): void {
    saveAudioSettings(this.settings);
  }
}
