import { describe, expect, it } from "vitest";
import {
  VectorSiegeSimulation,
  type SimulationInput,
} from "../../src/shared-simulation";

const quietStart = (simulation: VectorSiegeSimulation) => {
  simulation.start({ spawnWave: false });
};

const tick = (
  simulation: VectorSiegeSimulation,
  input: SimulationInput,
  count: number,
) => {
  for (let index = 0; index < count; index += 1) simulation.step(input);
};

describe("Vector Siege deterministic simulation", () => {
  it("normalizes movement and clamps the player to arena bounds", () => {
    const simulation = new VectorSiegeSimulation({
      arena: { width: 320, height: 240 },
      playerStart: { x: 160, y: 120 },
      playerSpeed: 120,
    });
    quietStart(simulation);

    tick(simulation, { moveX: 1, moveY: 1 }, 60);
    const diagonal = simulation.getState().player;
    expect(diagonal.x).toBeGreaterThan(230);
    expect(diagonal.y).toBeGreaterThan(190);

    tick(simulation, { moveX: 1, moveY: 0 }, 120);
    const bounded = simulation.getState().player;
    expect(bounded.x).toBe(304);
    expect(bounded.y).toBeCloseTo(diagonal.y);
  });

  it("fires from pointer input and resolves projectile/enemy collision and score", () => {
    const simulation = new VectorSiegeSimulation({
      arena: { width: 1000, height: 600 },
      playerStart: { x: 200, y: 300 },
      projectileSpeed: 600,
    });
    quietStart(simulation);
    const enemyId = simulation.spawnEnemy("chaser", { x: 340, y: 300 });

    simulation.step({ pointer: { x: 340, y: 300, down: true } });
    tick(simulation, { pointer: { x: 340, y: 300, down: false } }, 20);

    const state = simulation.getState();
    expect(state.enemies.some((enemy) => enemy.id === enemyId)).toBe(false);
    expect(state.score).toBe(100);
    expect(state.projectiles).toHaveLength(0);
  });

  it("keeps projectiles inside the simulation contract and removes them at bounds", () => {
    const simulation = new VectorSiegeSimulation({
      arena: { width: 320, height: 240 },
      playerStart: { x: 160, y: 120 },
      projectileSpeed: 600,
    });
    quietStart(simulation);

    simulation.step({ fire: true, aim: { x: 0, y: 120 } });
    tick(simulation, {}, 60);

    expect(simulation.getState().projectiles).toHaveLength(0);
  });

  it("has distinct enemy variants and spawns the opening wave outside the player radius", () => {
    const simulation = new VectorSiegeSimulation({
      seed: 42,
      arena: { width: 1200, height: 700 },
      playerStart: { x: 600, y: 350 },
      initialEnemiesPerWave: 6,
      spawnRadius: 260,
    });
    simulation.start();
    const state = simulation.getState();
    const variants = new Set(state.enemies.map((enemy) => enemy.variant));

    expect(variants.size).toBeGreaterThanOrEqual(2);
    for (const enemy of state.enemies) {
      expect(Math.hypot(enemy.x - state.player.x, enemy.y - state.player.y)).toBeGreaterThanOrEqual(259);
    }
  });

  it("applies contact damage once, then honors the invulnerability window", () => {
    const simulation = new VectorSiegeSimulation({
      arena: { width: 640, height: 480 },
      playerStart: { x: 320, y: 240 },
      playerMaxHealth: 3,
      invulnerabilityTicks: 30,
    });
    quietStart(simulation);
    simulation.spawnEnemy("chaser", { x: 320, y: 240 });

    simulation.step();
    expect(simulation.getState().player.health).toBe(2);
    tick(simulation, {}, 20);
    expect(simulation.getState().player.health).toBe(2);
    tick(simulation, {}, 12);
    expect(simulation.getState().player.health).toBe(1);
    expect(simulation.getState().player.hitFlashTicks).toBeGreaterThan(0);
  });

  it("advances waves deterministically after the last enemy is defeated", () => {
    const simulation = new VectorSiegeSimulation({
      seed: 7,
      arena: { width: 1000, height: 600 },
      playerStart: { x: 200, y: 300 },
      initialEnemiesPerWave: 1,
      waveEnemyGrowth: 1,
      projectileSpeed: 600,
      spawnRadius: 120,
      enemyStats: { chaser: { speed: 0 }, striker: { speed: 0 } },
    });
    simulation.start();
    const first = simulation.getState().enemies[0];
    simulation.step({ fire: true, aim: { x: first.x, y: first.y } });
    tick(simulation, { aim: { x: first.x, y: first.y } }, 30);

    const state = simulation.getState();
    expect(state.score).toBeGreaterThan(0);
    expect(state.wave).toBe(2);
    expect(state.enemies).toHaveLength(2);
  });

  it("pauses simulation time, resumes, and restarts without a page reload", () => {
    const simulation = new VectorSiegeSimulation({ seed: 9 });
    simulation.start({ spawnWave: false });
    simulation.step({ moveX: 1 });
    simulation.pause();
    const paused = simulation.getState();
    simulation.step({ moveX: -1 });
    expect(simulation.getState()).toEqual(paused);

    simulation.resume();
    simulation.step({ moveX: -1 });
    expect(simulation.getState().tick).toBe(paused.tick + 1);

    simulation.restart(123);
    const restarted = simulation.getState();
    expect(restarted.status).toBe("running");
    expect(restarted.tick).toBe(0);
    expect(restarted.seed).toBe(123);
    expect(restarted.score).toBe(0);
  });

  it("records a terminal seed and tick and reproduces it for the same scripted inputs", () => {
    const create = () => {
      const simulation = new VectorSiegeSimulation({
        seed: 101,
        arena: { width: 640, height: 480 },
        playerStart: { x: 320, y: 240 },
        playerMaxHealth: 1,
      });
      quietStart(simulation);
      simulation.spawnEnemy("tank", { x: 320, y: 240 });
      return simulation;
    };
    const first = create();
    const second = create();
    for (let index = 0; index < 100 && first.getState().status !== "game-over"; index += 1) {
      const input = index % 10 === 0 ? { fire: true, aim: { x: 0, y: 0 } } : {};
      first.step(input);
      second.step(input);
    }

    expect(first.getState().status).toBe("game-over");
    expect(first.getState().terminal).toEqual(second.getState().terminal);
    expect(first.getState().terminal).toEqual({ seed: 101, finalTick: 1, score: 0, wave: 1 });
  });
});
