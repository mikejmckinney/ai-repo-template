import { describe, expect, it } from "vitest";
import {
  ARENA_BOUNDS,
  ArenaSimulation,
  INVULNERABILITY_TICKS,
  PLAYER_RADIUS,
} from "../../src/game/simulation";

describe("ArenaSimulation", () => {
  it("moves on a fixed timestep and remains inside the arena", () => {
    const simulation = new ArenaSimulation("movement-seed");
    simulation.start();
    const startX = simulation.player.x;
    const startY = simulation.player.y;

    for (let tick = 0; tick < 30; tick += 1) {
      simulation.step({ right: true, up: true });
    }

    expect(simulation.player.x).toBeGreaterThan(startX);
    expect(simulation.player.y).toBeLessThan(startY);
    expect(simulation.player.x).toBeGreaterThanOrEqual(ARENA_BOUNDS.left + PLAYER_RADIUS);
    expect(simulation.player.x).toBeLessThanOrEqual(ARENA_BOUNDS.right - PLAYER_RADIUS);
    expect(simulation.player.y).toBeGreaterThanOrEqual(ARENA_BOUNDS.top + PLAYER_RADIUS);
    expect(simulation.player.y).toBeLessThanOrEqual(ARENA_BOUNDS.bottom - PLAYER_RADIUS);

    for (let tick = 0; tick < 500; tick += 1) {
      simulation.step({ left: true, down: true });
    }
    expect(simulation.player.x).toBe(ARENA_BOUNDS.left + PLAYER_RADIUS);
    expect(simulation.player.y).toBe(ARENA_BOUNDS.bottom - PLAYER_RADIUS);
  });

  it("applies contact damage once and then honors invulnerability", () => {
    const simulation = new ArenaSimulation("damage-seed");
    simulation.start();
    const enemy = simulation.enemies[0];
    enemy.x = simulation.player.x;
    enemy.y = simulation.player.y;

    const firstEvents = simulation.step();
    expect(firstEvents.some((event) => event.type === "playerHit")).toBe(true);
    expect(simulation.player.health).toBe(2);

    for (let tick = 0; tick < INVULNERABILITY_TICKS - 1; tick += 1) {
      enemy.x = simulation.player.x;
      enemy.y = simulation.player.y;
      simulation.step();
    }
    expect(simulation.player.health).toBe(2);
  });

  it("collides bullets with enemies and awards explicit defeat points", () => {
    const simulation = new ArenaSimulation("combat-seed");
    simulation.start();
    simulation.enemies.length = 0;
    const target = simulation.spawnEnemy("chaser", simulation.player.x + 120, simulation.player.y);

    let events = [] as ReturnType<ArenaSimulation["step"]>;
    for (let tick = 0; tick < 30; tick += 1) {
      events = events.concat(
        simulation.step({ fire: true, aimX: target.x, aimY: target.y }),
      );
      if (simulation.score > 0) break;
    }

    expect(events.some((event) => event.type === "enemyHit")).toBe(false);
    expect(events.some((event) => event.type === "enemyDefeated")).toBe(true);
    expect(simulation.score).toBe(100);
  });

  it("increases wave size deterministically and includes distinct enemy variants", () => {
    const simulation = new ArenaSimulation("wave-seed");
    const startEvents = simulation.start();
    expect(startEvents).toEqual([{ type: "waveStart", wave: 1, count: 4 }]);
    expect(simulation.enemies.map((enemy) => enemy.kind)).toEqual([
      "chaser",
      "striker",
      "chaser",
      "striker",
    ]);

    simulation.enemies.length = 0;
    const waveTwoEvents = simulation.step();
    expect(waveTwoEvents).toContainEqual({ type: "waveStart", wave: 2, count: 5 });
    expect(simulation.enemies).toHaveLength(5);
  });

  it("reaches the same terminal state for the same seed and scripted inputs", () => {
    const run = (seed: string) => {
      const simulation = new ArenaSimulation(seed);
      simulation.start();
      const damageTarget = simulation.enemies[0];
      for (let tick = 0; tick < 2400 && simulation.status !== "gameover"; tick += 1) {
        if (tick % INVULNERABILITY_TICKS === 0) {
          damageTarget.x = simulation.player.x;
          damageTarget.y = simulation.player.y;
          damageTarget.speed = 0;
        }
        simulation.step({
          right: tick % 90 < 30,
          left: tick % 90 >= 60,
        });
      }
      return simulation.snapshot();
    };

    const first = run("terminal-seed");
    const second = run("terminal-seed");
    expect(first.status).toBe("gameover");
    expect(second).toEqual(first);
    expect(first.completion?.seed).toBe("terminal-seed");
    expect(first.completion?.finalTick).toBe(first.tick);
  });
});
