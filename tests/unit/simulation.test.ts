import { describe, expect, it } from "vitest";
import {
  ARENA_HEIGHT,
  ARENA_MARGIN,
  ARENA_WIDTH,
  ArenaSimulation,
  PLAYER_RADIUS,
  type InputFrame,
} from "../../src/game/simulation";

function runScript(seed: number, frames: InputFrame[], ticks: number): ReturnType<ArenaSimulation["getSnapshot"]> {
  const simulation = new ArenaSimulation({ seed });
  simulation.start();
  for (let tick = 0; tick < ticks; tick += 1) {
    simulation.step(frames[tick % frames.length]);
  }
  return simulation.getSnapshot();
}

describe("ArenaSimulation", () => {
  it("moves with normalized diagonal input and clamps the player to the arena", () => {
    const simulation = new ArenaSimulation({ seed: 11 });
    simulation.start();
    const start = simulation.getSnapshot().player;

    simulation.step({ right: true, down: true });
    const moved = simulation.getSnapshot().player;
    expect(moved.x).toBeGreaterThan(start.x);
    expect(moved.y).toBeGreaterThan(start.y);

    for (let tick = 0; tick < 1000; tick += 1) {
      simulation.step({ right: true, down: true });
    }
    const clamped = simulation.getSnapshot().player;
    expect(clamped.x).toBe(ARENA_WIDTH - ARENA_MARGIN - PLAYER_RADIUS);
    expect(clamped.y).toBe(ARENA_HEIGHT - ARENA_MARGIN - PLAYER_RADIUS);
  });

  it("fires projectiles, damages explicit enemy health, scores defeats, and removes projectiles at bounds", () => {
    const simulation = new ArenaSimulation({ seed: 12 });
    simulation.start();
    simulation.drainEvents();
    const initialEnemyCount = simulation.getSnapshot().enemies.length;
    let defeated = false;

    for (let tick = 0; tick < 260 && !defeated; tick += 1) {
      const enemy = simulation.getSnapshot().enemies[0];
      simulation.step(enemy ? { fire: true, aimX: enemy.x, aimY: enemy.y } : {});
      defeated = simulation.drainEvents().some((event) => event.type === "enemyDefeated");
    }

    const scored = simulation.getSnapshot();
    expect(defeated).toBe(true);
    expect(scored.score).toBeGreaterThan(0);
    expect(scored.enemies.length).toBe(initialEnemyCount - 1);

    simulation.step({ fire: true, aimX: simulation.getSnapshot().player.x, aimY: 0 });
    simulation.drainEvents();
    for (let tick = 0; tick < 90; tick += 1) {
      simulation.step({ aimX: simulation.getSnapshot().player.x, aimY: 0 });
      simulation.drainEvents();
    }
    expect(simulation.getSnapshot().projectiles.length).toBe(0);
  });

  it("applies contact damage once, opens an invulnerability window, and transitions to game over", () => {
    const simulation = new ArenaSimulation({ seed: 13 });
    simulation.start();
    simulation.drainEvents();
    let firstHitTick: number | null = null;
    let healthAfterHit = 0;

    for (let tick = 0; tick < 2200 && firstHitTick === null; tick += 1) {
      simulation.step();
      const events = simulation.drainEvents();
      if (events.some((event) => event.type === "playerHit")) {
        firstHitTick = simulation.getSnapshot().tick;
        healthAfterHit = simulation.getSnapshot().player.health;
      }
    }

    expect(firstHitTick).not.toBeNull();
    expect(simulation.getSnapshot().player.invulnerableUntilTick).toBeGreaterThan(firstHitTick ?? 0);
    for (let tick = 0; tick < 20; tick += 1) {
      simulation.step();
      simulation.drainEvents();
    }
    expect(simulation.getSnapshot().player.health).toBe(healthAfterHit);

    while (simulation.getSnapshot().status === "running") {
      simulation.step();
      simulation.drainEvents();
      if (simulation.getSnapshot().tick > 5000) {
        throw new Error("contact damage did not reach game over within the deterministic test budget");
      }
    }
    const completed = simulation.getSnapshot();
    expect(completed.status).toBe("gameover");
    expect(completed.completedGame?.seed).toBe(13);
    expect(completed.completedGame?.finalTick).toBe(completed.tick);
  });

  it("progresses waves deterministically and keeps pause outside the simulation clock", () => {
    const simulation = new ArenaSimulation({ seed: 14 });
    simulation.start();
    const firstWave = simulation.getSnapshot().wave;
    const initialEnemies = simulation.getSnapshot().enemies;
    expect(new Set(initialEnemies.map((enemy) => enemy.kind)).size).toBeGreaterThanOrEqual(2);
    for (const enemy of initialEnemies) {
      expect(Math.hypot(enemy.x - simulation.getSnapshot().player.x, enemy.y - simulation.getSnapshot().player.y)).toBeGreaterThanOrEqual(simulation.spawnRadius);
    }
    simulation.pause();
    const pausedTick = simulation.getSnapshot().tick;
    simulation.step({ right: true, fire: true });
    expect(simulation.getSnapshot().tick).toBe(pausedTick);
    simulation.resume();

    let startedSecondWave = false;
    for (let tick = 0; tick < 1800 && !startedSecondWave; tick += 1) {
      const snapshot = simulation.getSnapshot();
      const enemy = snapshot.enemies[0];
      simulation.step(enemy ? { fire: true, aimX: enemy.x, aimY: enemy.y } : {});
      startedSecondWave = simulation.drainEvents().some((event) => event.type === "waveStarted" && event.wave === 2);
    }
    expect(firstWave).toBe(1);
    expect(startedSecondWave).toBe(true);
    const secondWave = simulation.getSnapshot();
    expect(secondWave.wave).toBe(2);
    expect(secondWave.enemies.length).toBeGreaterThan(initialEnemies.length);
    expect(Math.max(...secondWave.enemies.map((enemy) => enemy.speed))).toBeGreaterThan(Math.max(...initialEnemies.map((enemy) => enemy.speed)));
  });

  it("reaches the same state for the same seed and scripted inputs", () => {
    const frames: InputFrame[] = [
      { up: true, fire: true, aimX: 1120, aimY: 360 },
      { right: true, fire: true, aimX: 960, aimY: 600 },
      { down: true, left: true, aimX: 180, aimY: 220 },
      { left: true, fire: false, aimX: 640, aimY: 360 },
    ];
    const first = runScript(991, frames, 3600);
    const second = runScript(991, frames, 3600);
    expect(first.status).toBe("gameover");
    expect(first.completedGame).not.toBeNull();
    expect(second).toEqual(first);
  });
});
