export interface AudioSettings {
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
}

const AUDIO_SETTINGS_KEY = "vector-siege.audio-settings.v1";
const HIGH_SCORE_KEY = "vector-siege.high-score.v1";

export const DEFAULT_AUDIO_SETTINGS: AudioSettings = {
  musicVolume: 0.42,
  effectsVolume: 0.68,
  muted: false,
};

function getStorage(storage?: Storage): Storage | undefined {
  if (storage) return storage;
  if (typeof window === "undefined") return undefined;
  return window.localStorage;
}

export function loadAudioSettings(storage?: Storage): AudioSettings {
  const store = getStorage(storage);
  if (!store) return { ...DEFAULT_AUDIO_SETTINGS };

  const raw = store.getItem(AUDIO_SETTINGS_KEY);
  if (!raw) return { ...DEFAULT_AUDIO_SETTINGS };

  try {
    const parsed = JSON.parse(raw) as Partial<AudioSettings>;
    return {
      musicVolume: clampVolume(parsed.musicVolume ?? DEFAULT_AUDIO_SETTINGS.musicVolume),
      effectsVolume: clampVolume(parsed.effectsVolume ?? DEFAULT_AUDIO_SETTINGS.effectsVolume),
      muted: parsed.muted ?? DEFAULT_AUDIO_SETTINGS.muted,
    };
  } catch (error) {
    console.warn("Vector Siege audio settings were invalid and have been reset.", error);
    return { ...DEFAULT_AUDIO_SETTINGS };
  }
}

export function saveAudioSettings(settings: AudioSettings, storage?: Storage): void {
  const store = getStorage(storage);
  store?.setItem(AUDIO_SETTINGS_KEY, JSON.stringify(settings));
}

export function loadHighScore(storage?: Storage): number {
  const store = getStorage(storage);
  const value = Number(store?.getItem(HIGH_SCORE_KEY) ?? 0);
  return Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
}

export function saveHighScore(score: number, storage?: Storage): number {
  const next = Math.max(loadHighScore(storage), Math.floor(score));
  getStorage(storage)?.setItem(HIGH_SCORE_KEY, String(next));
  return next;
}

export function clampVolume(value: number): number {
  return Math.min(1, Math.max(0, Number.isFinite(value) ? value : 0));
}
