import type { SimulationSnapshot } from "../shared-simulation/types";
import { UI_SELECTORS } from "./constants";
import { DEFAULT_AUDIO_SETTINGS, type AudioSettings } from "./persistence";

export interface UiHandlers {
  onStart: () => void;
  onPause: () => void;
  onResume: () => void;
  onMute: () => void;
  onRestart: () => void;
  onMusicVolume: (value: number) => void;
  onEffectsVolume: (value: number) => void;
}

type TextElement = HTMLElement;

export class GameUi {
  private readonly status: TextElement;
  private readonly score: TextElement;
  private readonly wave: TextElement;
  private readonly health: TextElement;
  private readonly highScore: TextElement;
  private readonly finalScore: TextElement;
  private readonly seed: TextElement;
  private readonly menu: HTMLElement;
  private readonly hud: HTMLElement;
  private readonly gameOver: HTMLElement;
  private readonly start: HTMLButtonElement;
  private readonly pause: HTMLButtonElement;
  private readonly resume: HTMLButtonElement;
  private readonly mute: HTMLButtonElement;
  private readonly restart: HTMLButtonElement;
  private readonly musicVolume: HTMLInputElement;
  private readonly effectsVolume: HTMLInputElement;

  public constructor(root: Document = document) {
    this.status = required(root, UI_SELECTORS.status);
    this.score = required(root, UI_SELECTORS.score);
    this.wave = required(root, UI_SELECTORS.wave);
    this.health = required(root, UI_SELECTORS.health);
    this.highScore = required(root, UI_SELECTORS.highScore);
    this.finalScore = required(root, "final-score");
    this.seed = required(root, UI_SELECTORS.seed);
    this.menu = required(root, UI_SELECTORS.menu);
    this.hud = required(root, UI_SELECTORS.hud);
    this.gameOver = required(root, UI_SELECTORS.gameOver);
    this.start = required(root, UI_SELECTORS.start);
    this.pause = required(root, UI_SELECTORS.pause);
    this.resume = required(root, UI_SELECTORS.resume);
    this.mute = required(root, UI_SELECTORS.mute);
    this.restart = required(root, UI_SELECTORS.restart);
    this.musicVolume = required(root, UI_SELECTORS.musicVolume);
    this.effectsVolume = required(root, UI_SELECTORS.effectsVolume);
  }

  public bind(handlers: UiHandlers): void {
    this.start.addEventListener("click", handlers.onStart);
    this.pause.addEventListener("click", handlers.onPause);
    this.resume.addEventListener("click", handlers.onResume);
    this.mute.addEventListener("click", handlers.onMute);
    this.restart.addEventListener("click", handlers.onRestart);
    this.musicVolume.addEventListener("input", () => handlers.onMusicVolume(Number(this.musicVolume.value)));
    this.effectsVolume.addEventListener("input", () => handlers.onEffectsVolume(Number(this.effectsVolume.value)));
  }

  public applyAudioSettings(settings: AudioSettings = DEFAULT_AUDIO_SETTINGS): void {
    this.musicVolume.value = String(settings.musicVolume);
    this.effectsVolume.value = String(settings.effectsVolume);
    this.setMuted(settings.muted);
  }

  public setPhase(phase: SimulationSnapshot["phase"]): void {
    const menu = phase === "menu";
    const active = phase === "running" || phase === "paused";
    const paused = phase === "paused";
    const over = phase === "game-over";

    this.menu.hidden = !menu;
    this.hud.hidden = !active;
    this.gameOver.hidden = !over;
    this.start.disabled = !menu;
    this.pause.hidden = !active || paused;
    this.resume.hidden = !paused;
    this.restart.hidden = menu;

    if (menu) this.setStatus("READY // AWAITING PILOT");
    if (active && !paused) this.setStatus("MISSION ACTIVE");
    if (paused) this.setStatus("PAUSED // SIMULATION HOLD");
    if (over) this.setStatus("GAME OVER // RUN TERMINATED");
  }

  public update(snapshot: SimulationSnapshot, highScore: number): void {
    this.score.textContent = String(snapshot.score).padStart(5, "0");
    this.finalScore.textContent = String(snapshot.score).padStart(5, "0");
    this.wave.textContent = String(snapshot.wave).padStart(2, "0");
    this.health.textContent = `${snapshot.player.health}/${snapshot.player.maxHealth}`;
    this.highScore.textContent = String(highScore).padStart(5, "0");
    this.seed.textContent = snapshot.seed;
    this.setPhase(snapshot.phase);
    if (snapshot.phase === "game-over") {
      this.setStatus(`GAME OVER // SCORE ${snapshot.score}`);
    }
  }

  public setMuted(muted: boolean): void {
    this.mute.textContent = muted ? "Unmute" : "Mute";
    this.mute.setAttribute("aria-pressed", String(muted));
    this.mute.classList.toggle("is-muted", muted);
  }

  public setStatus(text: string): void {
    this.status.textContent = text;
  }
}

function required<T extends Element>(root: Document, id: string): T {
  const element = root.getElementById(id);
  if (!element) throw new Error(`Vector Siege UI element #${id} is missing.`);
  return element as unknown as T;
}
