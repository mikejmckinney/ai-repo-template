import { describe, expect, it } from "vitest";

import {
  GameState,
  Simulation,
  SimulationEvent,
  SimulationInput,
} from "../../src/game/simulation";

const idleInput = (overrides: Partial<SimulationInput> = {}): SimulationInput => ({
  moveX: 0,
  moveY: 0,
  aimX: 0,
  aimY: 0,
  fire: false,
  ...overrides,
});

const eventsOfType = <T extends SimulationEvent["type"]>(
  events: SimulationEvent[],
  type: T,
): Array<Extract<SimulationEvent, { type: T }>> =>
  events.filter((event): event is Extract<SimulationEvent, { type: T }> => event.type === type);

describe("Simulation", () => {
  it("moves the player and clamps it inside the arena", () => {
    const simulation = new Simulation({ seed: 11, width: 320, height: 200, spawnRadius: 60 });

    for (let tick = 0; tick < 120; tick += 1) {
      simulation.step(idleInput({ moveX: -1, moveY: -1 }));
    }

    expect(simulation.state.player.x).toBe(simulation.state.player.radius);
    expect(simulation.state.player.y).toBe(simulation.state.player.radius);

    for (let tick = 0; tick < 240; tick += 1) {
      simulation.step(idleInput({ moveX: 1, moveY: 1 }));
    }

    expect(simulation.state.player.x).toBe(320 - simulation.state.player.radius);
    expect(simulation.state.player.y).toBe(200 - simulation.state.player.radius);
  });

  it("spawns wave one beyond the configured player radius with distinct enemies", () => {
    const spawnRadius = 210;
    const simulation = new Simulation({ seed: 23, width: 800, height: 600, spawnRadius });
    const player = simulation.state.player;

    for (const enemy of simulation.state.enemies) {
      expect(Math.hypot(enemy.x - player.x, enemy.y - player.y)).toBeGreaterThanOrEqual(
        spawnRadius,
      );
    }
    expect(simulation.state.enemies.map((enemy) => enemy.kind)).toEqual([
      "chaser",
      "striker",
      "chaser",
    ]);
    expect(simulation.state.enemies[0].speed).not.toBe(simulation.state.enemies[1].speed);
    expect(simulation.step(idleInput()).some((event) => event.type === "wave-start")).toBe(true);
  });

  it("fires projectiles that hit and defeat an enemy for score", () => {
    const simulation = new Simulation({ seed: 31, width: 800, height: 600, spawnRadius: 210 });
    const target = simulation.state.enemies[0];
    const targetId = target.id;
    const targetScore = target.scoreValue;
    const allEvents: SimulationEvent[] = [];

    allEvents.push(
      ...simulation.step(
        idleInput({ aimX: target.x, aimY: target.y, fire: true, firePressed: true }),
      ),
    );
    for (let tick = 0; tick < 80 && simulation.state.score === 0; tick += 1) {
      allEvents.push(...simulation.step(idleInput()));
    }

    const hitEvents = eventsOfType(allEvents, "enemy-hit");
    const defeatedEvents = eventsOfType(allEvents, "enemy-defeated");
    expect(hitEvents.some((event) => event.enemyId === targetId && event.damage > 0)).toBe(true);
    expect(defeatedEvents.some((event) => event.enemyId === targetId)).toBe(true);
    expect(simulation.state.score).toBe(targetScore);
    expect(simulation.state.enemies.some((enemy) => enemy.id === targetId)).toBe(false);
  });

  it("expires projectiles at arena bounds", () => {
    const simulation = new Simulation({ seed: 37, width: 640, height: 360, spawnRadius: 120 });
    simulation.step(idleInput({ aimX: -1000, aimY: simulation.state.player.y, fire: true }));

    for (let tick = 0; tick < 100; tick += 1) {
      simulation.step(idleInput());
    }

    expect(simulation.state.projectiles).toHaveLength(0);
  });

  it("applies contact damage once per invulnerability window and records game over", () => {
    const simulation = new Simulation({ seed: 41 });
    const player = simulation.state.player;
    const contactEnemy = simulation.state.enemies[0];
    player.maxHealth = 2;
    player.health = 2;
    contactEnemy.x = player.x;
    contactEnemy.y = player.y;
    contactEnemy.speed = 0;

    const firstEvents = simulation.step(idleInput());
    expect(eventsOfType(firstEvents, "player-hit")).toHaveLength(1);
    expect(player.health).toBe(1);
    expect(player.invulnerabilityTicks).toBeGreaterThan(0);

    const immediateEvents = simulation.step(idleInput());
    expect(eventsOfType(immediateEvents, "player-hit")).toHaveLength(0);
    expect(player.health).toBe(1);

    let gameOverEvents: SimulationEvent[] = [];
    for (let tick = 0; tick < 60 && simulation.state.status === "running"; tick += 1) {
      const events = simulation.step(idleInput());
      gameOverEvents = gameOverEvents.concat(eventsOfType(events, "game-over"));
    }

    expect(gameOverEvents).toHaveLength(1);
    expect(simulation.state.status).toBe("gameover");
    expect(simulation.state.completedRecord).toMatchObject({
      seed: 41,
      score: 0,
      finalTick: simulation.state.tick,
      tick: simulation.state.tick,
    });
  });

  it("starts the next deterministic wave after all current enemies are defeated", () => {
    const simulation = new Simulation({ seed: 53, width: 800, height: 600, spawnRadius: 210 });
    for (const enemy of simulation.state.enemies) {
      // Keep this wave-transition fixture focused on spawning rather than
      // waiting for the striker's two normal health points.
      enemy.health = 1;
      enemy.maxHealth = 1;
      enemy.speed = 0;
    }

    const allEvents: SimulationEvent[] = [];
    for (let tick = 0; tick < 240 && simulation.state.wave === 1; tick += 1) {
      const target = simulation.state.enemies[0];
      allEvents.push(
        ...simulation.step(
          idleInput({ aimX: target.x, aimY: target.y, fire: true }),
        ),
      );
    }

    expect(simulation.state.wave).toBe(2);
    expect(simulation.state.enemies.length).toBeGreaterThan(0);
    expect(eventsOfType(allEvents, "wave-start").some((event) => event.wave === 2)).toBe(true);
  });

  it("replays to the same terminal state for the same seed and scripted inputs", () => {
    const scriptedInputs: SimulationInput[] = Array.from({ length: 520 }, (_, tick) => ({
      moveX: tick % 120 < 60 ? 1 : -1,
      moveY: tick % 90 < 45 ? 0.5 : -0.5,
      aimX: 0,
      aimY: 0,
      fire: false,
    }));

    const run = (seed: number): GameState => {
      const simulation = new Simulation({ seed });
      for (const input of scriptedInputs) {
        simulation.step(input);
      }
      return JSON.parse(JSON.stringify(simulation.state)) as GameState;
    };

    const firstTerminalState = run(61);
    const secondTerminalState = run(61);

    expect(firstTerminalState).toEqual(secondTerminalState);
    expect(firstTerminalState.status).toBe("gameover");
    expect(firstTerminalState.completedRecord?.finalTick).toBe(
      firstTerminalState.completedRecord?.tick,
    );
  });
});

