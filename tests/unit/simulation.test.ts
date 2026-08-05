import { describe, expect, it } from "vitest";

import { Simulation } from "../../src/shared-simulation/simulation";
import type { StepInput } from "../../src/shared-simulation/types";

const idleInput = (overrides: Partial<StepInput> = {}): StepInput => ({
  up: false,
  down: false,
  left: false,
  right: false,
  fire: false,
  aimX: 0,
  aimY: 0,
  ...overrides,
});

const advance = (simulation: Simulation, ticks: number, input = idleInput()): void => {
  for (let tick = 0; tick < ticks; tick += 1) {
    simulation.step(input);
  }
};

const fireAtNearestEnemy = (simulation: Simulation): void => {
  const { enemies } = simulation.snapshot();
  const target = enemies[0];
  simulation.step(
    idleInput({
      fire: true,
      aimX: target?.x ?? simulation.snapshot().player.x + 1,
      aimY: target?.y ?? simulation.snapshot().player.y,
    }),
  );
};

describe("Simulation", () => {
  it("keeps movement inside the arena bounds", () => {
    const simulation = new Simulation({
      arena: { left: 0, top: 0, right: 640, bottom: 360 },
      playerHealth: 1000,
      seed: "movement-bounds",
    });
    simulation.start();

    advance(simulation, 240, idleInput({ right: true, down: true }));
    let snapshot = simulation.snapshot();
    expect(snapshot.player.x).toBeLessThanOrEqual(snapshot.arena.right - snapshot.player.radius);
    expect(snapshot.player.y).toBeLessThanOrEqual(snapshot.arena.bottom - snapshot.player.radius);

    advance(simulation, 240, idleInput({ left: true, up: true }));
    snapshot = simulation.snapshot();
    expect(snapshot.player.x).toBeGreaterThanOrEqual(snapshot.arena.left + snapshot.player.radius);
    expect(snapshot.player.y).toBeGreaterThanOrEqual(snapshot.arena.top + snapshot.player.radius);
  });

  it("fires bounded projectiles that defeat enemies and award score", () => {
    const simulation = new Simulation({
      arena: { left: 0, top: 0, right: 640, bottom: 360 },
      playerHealth: 1000,
      seed: "projectile-score",
      spawnRadius: 0,
    });
    simulation.start();
    const events = simulation.drainEvents();

    for (let tick = 0; tick < 900 && simulation.snapshot().score === 0; tick += 1) {
      fireAtNearestEnemy(simulation);
      events.push(...simulation.drainEvents());
    }

    expect(events.some((event) => event.type === "shot-fired")).toBe(true);
    expect(events.some((event) => event.type === "enemy-defeated")).toBe(true);
    expect(simulation.snapshot().score).toBeGreaterThan(0);

    advance(simulation, 120);
    expect(simulation.snapshot().projectiles).toHaveLength(0);
  });

  it("applies contact damage once during the invulnerability window", () => {
    const simulation = new Simulation({
      arena: { left: 0, top: 0, right: 360, bottom: 240 },
      playerHealth: 10,
      seed: "contact-damage",
      spawnRadius: 0,
    });
    simulation.start();
    simulation.drainEvents();

    const events = [] as ReturnType<typeof simulation.drainEvents>;
    for (let tick = 0; tick < 300 && !events.some((event) => event.type === "player-hit"); tick += 1) {
      simulation.step(idleInput());
      events.push(...simulation.drainEvents());
    }

    expect(events.some((event) => event.type === "player-hit")).toBe(true);
    const hitSnapshot = simulation.snapshot();
    expect(hitSnapshot.player.health).toBeLessThan(hitSnapshot.player.maxHealth);
    expect(hitSnapshot.player.invulnerableTicks).toBeGreaterThan(0);

    const healthAfterHit = hitSnapshot.player.health;
    simulation.step(idleInput());
    expect(simulation.snapshot().player.health).toBe(healthAfterHit);
  });

  it("advances to a harder deterministic wave after clearing the current wave", () => {
    const simulation = new Simulation({
      arena: { left: 0, top: 0, right: 640, bottom: 360 },
      playerHealth: 1000,
      seed: "waves",
      spawnRadius: 0,
    });
    simulation.start();
    simulation.drainEvents();

    const firstWave = simulation.snapshot().wave;
    const events = [] as ReturnType<typeof simulation.drainEvents>;
    for (let tick = 0; tick < 1800 && simulation.snapshot().wave === firstWave; tick += 1) {
      fireAtNearestEnemy(simulation);
      events.push(...simulation.drainEvents());
    }

    const snapshot = simulation.snapshot();
    expect(snapshot.wave).toBeGreaterThan(firstWave);
    expect(snapshot.enemies.length).toBeGreaterThan(0);
    expect(events).toContainEqual(expect.objectContaining({ type: "wave-start", wave: firstWave + 1 }));
  });

  it("supports menu, pause, resume, and restart lifecycle transitions", () => {
    const simulation = new Simulation({ seed: 11 });
    expect(simulation.snapshot().phase).toBe("menu");

    simulation.start();
    expect(simulation.snapshot().phase).toBe("running");
    expect(simulation.snapshot().wave).toBe(1);

    simulation.pause();
    const paused = simulation.snapshot();
    simulation.step(idleInput({ right: true }));
    expect(simulation.snapshot()).toEqual(paused);

    simulation.resume();
    simulation.step(idleInput());
    expect(simulation.snapshot().phase).toBe("running");
    expect(simulation.snapshot().tick).toBe(paused.tick + 1);

    simulation.restart("fresh-seed");
    const restarted = simulation.snapshot();
    expect(restarted.phase).toBe("running");
    expect(restarted.seed).toBe("fresh-seed");
    expect(restarted.tick).toBe(0);
    expect(restarted.score).toBe(0);
    expect(restarted.wave).toBe(1);
  });

  it("reaches the same terminal state for the same seed and scripted inputs", () => {
    const config = {
      arena: { left: 0, top: 0, right: 240, bottom: 180 },
      playerHealth: 1,
      seed: 77,
      spawnRadius: 0,
    };
    const first = new Simulation(config);
    const second = new Simulation(config);
    first.start();
    second.start();

    for (let tick = 0; tick < 600; tick += 1) {
      const input = idleInput({ aimX: 180, aimY: 20, fire: tick % 5 === 0 });
      first.step(input);
      second.step(input);
    }

    expect(first.snapshot().phase).toBe("game-over");
    expect(second.snapshot()).toEqual(first.snapshot());
    expect(first.snapshot().completedGame).toEqual(
      expect.objectContaining({ seed: "77", finalTick: first.snapshot().tick }),
    );
  });
});
