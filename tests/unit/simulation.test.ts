import { describe, expect, it } from "vitest";
import { ArenaSimulation, type InputFrame } from "../../src/shared-simulation/simulation";

const neutral: InputFrame = {
  moveX: 0,
  moveY: 0,
  aimX: 1200,
  aimY: 360,
  fire: false,
};

describe("ArenaSimulation", () => {
  it("moves the player with normalized input and keeps it inside the arena", () => {
    const simulation = new ArenaSimulation({ seed: "movement" });
    const start = simulation.snapshot().player;

    for (let tick = 0; tick < 60; tick += 1) {
      simulation.step({ ...neutral, moveX: 1, moveY: 1 });
    }

    const moved = simulation.snapshot().player;
    expect(moved.x).toBeGreaterThan(start.x);
    expect(moved.y).toBeGreaterThan(start.y);
    expect(Math.abs(moved.x - start.x)).toBeCloseTo(Math.abs(moved.y - start.y), 6);

    for (let tick = 0; tick < 600; tick += 1) {
      simulation.step({ ...neutral, moveX: -1, moveY: -1 });
    }
    const clamped = simulation.snapshot().player;
    expect(clamped.x).toBeGreaterThanOrEqual(72);
    expect(clamped.y).toBeGreaterThanOrEqual(72);
  });

  it("fires projectiles that collide with enemies and awards score on defeat", () => {
    const simulation = new ArenaSimulation({ seed: "combat" });
    const before = simulation.snapshot();
    expect(before.enemies[0]?.kind).toBe("chaser");

    for (let tick = 0; tick < 70; tick += 1) {
      simulation.step({ ...neutral, fire: true });
    }

    const after = simulation.snapshot();
    expect(after.shotsFired).toBeGreaterThan(0);
    expect(after.enemiesDefeated).toBeGreaterThan(0);
    expect(after.score).toBeGreaterThanOrEqual(100);
    expect(after.enemies.length).toBeLessThan(before.enemies.length);
  });

  it("applies contact damage once per invulnerability window", () => {
    const simulation = new ArenaSimulation({ seed: "damage" });
    const initialHealth = simulation.snapshot().player.health;

    expect(simulation.applyDamage()).toBe(true);
    expect(simulation.snapshot().player.health).toBe(initialHealth - 1);
    expect(simulation.applyDamage()).toBe(false);

    for (let tick = 0; tick < 60; tick += 1) {
      simulation.step(neutral);
    }
    expect(simulation.applyDamage()).toBe(true);
    expect(simulation.snapshot().player.health).toBe(initialHealth - 2);
  });

  it("raises the wave after all enemies are defeated", () => {
    const simulation = new ArenaSimulation({ seed: "waves" });
    const firstWave = simulation.snapshot();

    for (const enemy of firstWave.enemies) {
      simulation.damageEnemy(enemy.id, enemy.maxHealth);
    }
    expect(simulation.snapshot().enemies).toHaveLength(0);

    for (let tick = 0; tick < 46; tick += 1) {
      simulation.step(neutral);
    }

    const nextWave = simulation.snapshot();
    expect(nextWave.wave).toBe(2);
    expect(nextWave.enemies.length).toBeGreaterThan(firstWave.enemies.length);
    expect(nextWave.score).toBeGreaterThan(0);
  });

  it("spawns every wave outside the configured player radius", () => {
    const simulation = new ArenaSimulation({ seed: "spawn-radius", spawnRadius: 260 });
    const snapshot = simulation.snapshot();
    for (const enemy of snapshot.enemies) {
      const distance = Math.hypot(enemy.x - snapshot.player.x, enemy.y - snapshot.player.y);
      expect(distance).toBeGreaterThanOrEqual(260);
    }
  });

  it("transitions through pause, resume, game over, and restart", () => {
    const simulation = new ArenaSimulation({ seed: "lifecycle" });
    expect(simulation.pause()).toBe(true);
    const pausedTick = simulation.tick;
    simulation.step(neutral);
    expect(simulation.tick).toBe(pausedTick);
    expect(simulation.resume()).toBe(true);

    for (let count = 0; count < 5; count += 1) {
      simulation.step(neutral);
    }
    expect(simulation.applyDamage(99)).toBe(true);
    expect(simulation.phase).toBe("gameover");
    expect(simulation.snapshot().completedGame?.finalTick).toBe(simulation.tick);

    simulation.restart("lifecycle-restart");
    expect(simulation.phase).toBe("running");
    expect(simulation.tick).toBe(0);
    expect(simulation.snapshot().score).toBe(0);
    expect(simulation.snapshot().completedGame).toBeNull();
    expect(simulation.completedGames).toHaveLength(1);
  });

  it("reaches the same terminal state for the same seed and scripted inputs", () => {
    const runScript = (seed: string) => {
      const simulation = new ArenaSimulation({ seed });
      for (let tick = 0; tick < 240; tick += 1) {
        simulation.step({
          moveX: tick % 80 < 40 ? 1 : -1,
          moveY: tick % 120 < 60 ? 0.5 : -0.5,
          aimX: 1120,
          aimY: 360,
          fire: tick % 9 < 5,
        });
      }
      if (simulation.phase !== "gameover") {
        simulation.applyDamage(99);
      }
      return simulation.snapshot();
    };

    const first = runScript("deterministic-seed");
    const second = runScript("deterministic-seed");
    expect(first.phase).toBe("gameover");
    expect(second.phase).toBe("gameover");
    expect(second).toEqual(first);
  });
});
