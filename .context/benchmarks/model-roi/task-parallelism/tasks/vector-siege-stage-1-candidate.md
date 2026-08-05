# Vector Siege Stage 1 Candidate Task

Build a polished single-player top-down browser arena shooter from the supplied
minimal scaffold and benchmark-owned assets. Implement Stage 1 only. Do not add
replay, leaderboard, API, database, deployment, or publication behavior.

## Fixed Stack

- TypeScript, Vite, and Phaser 4.2.1
- Vitest for deterministic and unit tests
- Playwright for the evaluator journey
- Desktop Chrome at a 1280 by 720 target viewport

Do not replace the stack or regenerate, replace, or materially repaint files
under `public/benchmark-assets/vector-siege/`.

## Player And Controls

- Move with WASD or arrow keys.
- Aim with the pointer.
- Fire projectiles with pointer input or Space.
- Keep the player within the arena.
- Show hit feedback and a short invulnerability window after damage.

## Enemies And Waves

- Spawn enemies outside a configurable radius from the player.
- Enemies pursue the player and cause damage on contact.
- Increase wave difficulty deterministically.
- Use at least two supplied enemy variants with distinct behavior or stats.

## Combat And Scoring

- Projectiles collide with enemies and arena bounds.
- Enemies have explicit health and defeat behavior.
- Award score for enemy defeats.
- Track score, wave, player health, and game-over state.

## Lifecycle, Visuals, Audio, And UI

- Start screen with controls and supplied branding/artwork.
- Running HUD, pause/resume, game-over screen, and restart without page reload.
- Persist local high score, music/effects volume, and mute state.
- Use browser-autoplay-safe audio unlock, looping menu/gameplay music, gameplay
  sound effects, and correct pause/resume/restart/game-over behavior.
- Keep audio state out of deterministic simulation.
- Integrate the supplied visual and audio bundles with readable composition,
  consistent scaling/origins, and no stretching, clipping, or texture halos.

## Determinism And Architecture

- Use a fixed-timestep or equivalent deterministic simulation contract.
- Support an injectable random seed.
- Separate rendering/audio from simulation enough to test combat and waves
  without pixel or audio inspection.
- Record the seed and final simulation tick for every completed game.

## Verification

- Unit tests cover representative movement, collision, damage, scoring, waves,
  and state transitions.
- A deterministic simulation test reaches the same terminal state from the same
  seed and scripted inputs.
- A Playwright journey starts a game, unlocks audio, moves, fires, reaches a
  scored state, pauses/resumes, changes mute state, and restarts or reaches game
  over without uncaught browser-console errors.
- `npm run build`, `npm test`, and `npm run test:e2e` pass.

## Constraints

- Work only in this candidate worktree.
- Do not push, deploy, publish, access provider credentials, or modify
  `.agents/`, `TASK.md`, or the supplied benchmark assets.
- Use available repository skills only when useful; do not create a
  Vector-Siege-specific skill.
