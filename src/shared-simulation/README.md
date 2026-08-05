# Shared Simulation

`VectorSiegeSimulation` is the Phaser-independent, fixed-timestep game model.
It owns gameplay state and deterministic rules; a scene only needs to translate
keyboard and pointer input into `SimulationInput`, call `step()` once per fixed
tick (or `advance()` with elapsed milliseconds), render `getState()`, and
consume `drainEvents()` for audio and effects.

```ts
const simulation = new VectorSiegeSimulation({ seed: 1337 });
simulation.start();
simulation.step({ moveX: 1, pointer: { x: 900, y: 360, down: true } });
const snapshot = simulation.getState();
```

The public API is exported from `src/shared-simulation/index.ts`. `step()` is
the canonical deterministic operation at 60 Hz. `advance()` accumulates real
time but delegates each complete fixed step to the same simulation path. The
model has no browser, Phaser, audio, storage, or rendering dependencies.
