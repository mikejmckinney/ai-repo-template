import { describe, expect, it } from "vitest";

import {
  ARENA_BOUNDS,
  INVULNERABILITY_TICKS,
  createSimulation,
  damageSimulation,
  pauseSimulation,
  resumeSimulation,
  setPlayerPosition,
  snapshotSimulation,
  startSimulation,
  stepSimulation,
} from "../../src/shared-simulation/simulation";

describe("Vector Siege deterministic simulation", () => {
  it("moves with normalized input and clamps the player to the arena", () => {
    const state = startSimulation("movement");
    const startX = state.player.x;
    const startY = state.player.y;

    stepSimulation(state, { right: true, down: true });

    expect(state.player.x).toBeGreaterThan(startX);
    expect(state.player.y).toBeGreaterThan(startY);
    expect(Math.hypot(state.player.x - startX, state.player.y - startY)).toBeCloseTo(4.5, 5);

    setPlayerPosition(state, -1000, 10000);
    expect(state.player.x).toBe(ARENA_BOUNDS.left + state.player.radius);
    expect(state.player.y).toBe(ARENA_BOUNDS.bottom - state.player.radius);
  });

  it("fires, collides with an enemy, deals health damage, and awards score", () => {
    const state = startSimulation("combat");
    const target = state.enemies[0];
    state.enemies = [
      { ...target, x: state.player.x + 105, y: state.player.y, health: 1, maxHealth: 1 },
      { ...state.enemies[1], id: 999, x: state.player.x - 280, y: state.player.y - 180 },
    ];

    let events = [] as ReturnType<typeof stepSimulation>;
    for (let tick = 0; tick < 24 && state.score === 0; tick += 1) {
      events = stepSimulation(state, { fire: true, aimX: target.x, aimY: target.y });
    }

    expect(events.some((event) => event.type === "enemy-defeated")).toBe(true);
    expect(state.score).toBe(100);
    expect(state.kills).toBe(1);
    expect(state.enemies).toHaveLength(1);
  });

  it("removes projectiles when they leave the arena bounds", () => {
    const state = startSimulation("projectile-bounds");
    state.enemies = state.enemies.map((enemy) => ({ ...enemy, x: 640, y: 650 }));

    for (let tick = 0; tick < 100; tick += 1) {
      stepSimulation(state, { fire: tick === 0, aimX: 20, aimY: 405 });
    }

    expect(state.projectiles).toHaveLength(0);
  });

  it("protects the player during the invulnerability window", () => {
    const state = startSimulation("damage");

    expect(damageSimulation(state)).toEqual([{ type: "player-hit", x: 640, y: 405, health: 2 }]);
    expect(state.invulnerableTicks).toBe(INVULNERABILITY_TICKS);
    expect(damageSimulation(state)).toEqual([]);
    expect(state.health).toBe(2);

    state.invulnerableTicks = 0;
    damageSimulation(state);
    expect(state.health).toBe(1);
  });

  it("advances waves deterministically after the last enemy is defeated", () => {
    const state = startSimulation("waves");
    state.enemies = [];

    const events = stepSimulation(state);

    expect(state.wave).toBe(2);
    expect(state.waveTarget).toBe(7);
    expect(state.enemies).toHaveLength(7);
    expect(events).toContainEqual({ type: "wave-start", wave: 2, count: 7 });
  });

  it("spawns every enemy outside the configured player radius", () => {
    const state = startSimulation("spawn-radius", { enemySpawnRadius: 420 });
    for (const enemy of state.enemies) {
      expect(Math.hypot(enemy.x - state.player.x, enemy.y - state.player.y)).toBeGreaterThanOrEqual(420);
    }
  });

  it("transitions menu, pause, resume, game-over, and records the terminal tick", () => {
    const menu = createSimulation("lifecycle");
    expect(menu.status).toBe("menu");
    expect(pauseSimulation(menu)).toBe(false);

    const state = startSimulation("lifecycle");
    expect(pauseSimulation(state)).toBe(true);
    const pausedTick = state.tick;
    stepSimulation(state, { right: true });
    expect(state.tick).toBe(pausedTick);
    expect(resumeSimulation(state)).toBe(true);

    state.tick = 91;
    state.invulnerableTicks = 0;
    damageSimulation(state, 3);
    expect(state.status).toBe("game-over");
    expect(state.completion).toEqual({ seed: "lifecycle", finalTick: 91, score: 0, wave: 1 });
    expect(stepSimulation(state, { fire: true })).toEqual([]);
  });

  it("reaches the same terminal state from the same seed and scripted inputs", () => {
    const run = () => {
      const state = startSimulation("same-seed");
      const contactEnemy = state.enemies[0];
      state.enemies = [{ ...contactEnemy, x: state.player.x, y: state.player.y }];
      for (let tick = 0; tick < 720 && state.status === "running"; tick += 1) {
        stepSimulation(state, {
          fire: tick % 20 === 0,
          aimX: 920,
          aimY: 405,
        });
      }
      return snapshotSimulation(state);
    };

    const first = run();
    expect(first.status).toBe("game-over");
    expect(first.completion?.finalTick).toBeGreaterThan(0);
    expect(first).toEqual(run());
  });
});
