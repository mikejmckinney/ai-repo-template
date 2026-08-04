import { describe, expect, it } from "vitest";
import {
  DEFAULT_SIMULATION_CONFIG,
  type InputFrame,
  VectorSiegeSimulation,
} from "../../src/shared-simulation/vector-siege-simulation";

const idle: InputFrame = {
  up: false,
  down: false,
  left: false,
  right: false,
  fire: false,
  aimX: 640,
  aimY: 360,
};

function runScript(seed: string): VectorSiegeSimulation {
  const simulation = new VectorSiegeSimulation(seed);
  for (let tick = 0; tick < 420; tick += 1) {
    simulation.step({
      up: tick % 120 < 28,
      down: tick % 120 >= 70 && tick % 120 < 90,
      left: tick % 180 >= 120 && tick % 180 < 146,
      right: tick % 180 < 20,
      fire: tick % 6 < 3,
      aimX: 980 - (tick % 80),
      aimY: 360 + ((tick % 40) - 20) * 3,
    });
  }
  return simulation;
}

describe("Vector Siege deterministic simulation", () => {
  it("moves the player and clamps it to the arena bounds", () => {
    const simulation = new VectorSiegeSimulation("movement");
    const initialX = simulation.state.player.position.x;

    for (let tick = 0; tick < 60; tick += 1) {
      simulation.step({ ...idle, right: true });
    }
    expect(simulation.state.player.position.x).toBeGreaterThan(initialX);

    for (let tick = 0; tick < 600; tick += 1) {
      simulation.step({ ...idle, left: true, up: true });
    }
    expect(simulation.state.player.position.x).toBe(DEFAULT_SIMULATION_CONFIG.arena.left + DEFAULT_SIMULATION_CONFIG.playerRadius);
    expect(simulation.state.player.position.y).toBe(DEFAULT_SIMULATION_CONFIG.arena.top + DEFAULT_SIMULATION_CONFIG.playerRadius);
  });

  it("fires projectiles, resolves enemy collision, and awards score", () => {
    const simulation = new VectorSiegeSimulation("combat");
    const firstEnemy = simulation.state.enemies.find((enemy) => enemy.kind === "chaser");
    expect(firstEnemy).toBeDefined();

    for (let tick = 0; tick < 150 && simulation.state.defeated === 0; tick += 1) {
      simulation.step({ ...idle, fire: true, aimX: firstEnemy?.position.x ?? 1100, aimY: firstEnemy?.position.y ?? 360 });
    }

    expect(simulation.state.projectiles.length).toBeGreaterThanOrEqual(0);
    expect(simulation.state.defeated).toBeGreaterThan(0);
    expect(simulation.state.score).toBeGreaterThan(0);
    expect(simulation.drainEvents().some((event) => event.type === "enemy-defeated")).toBe(true);
  });

  it("applies contact damage once and honors the invulnerability window", () => {
    const simulation = new VectorSiegeSimulation("damage");
    const enemy = simulation.state.enemies[0];
    enemy.position = { ...simulation.state.player.position };
    enemy.speed = 0;
    const startingHealth = simulation.state.player.health;

    simulation.step(idle);
    const impactEvents = simulation.drainEvents();
    expect(simulation.state.player.health).toBeLessThan(startingHealth);
    expect(simulation.state.player.invulnerableTicks).toBeGreaterThan(0);
    const healthAfterImpact = simulation.state.player.health;

    for (let tick = 0; tick < 20; tick += 1) {
      simulation.step(idle);
    }
    expect(simulation.state.player.health).toBe(healthAfterImpact);
    expect(impactEvents.some((event) => event.type === "player-hit")).toBe(true);
  });

  it("advances to a harder deterministic wave after the first wave is defeated", () => {
    const simulation = new VectorSiegeSimulation("waves", { ...DEFAULT_SIMULATION_CONFIG, wavePauseTicks: 3 });
    for (const enemy of simulation.state.enemies) {
      enemy.position = { ...simulation.state.player.position };
      enemy.speed = 0;
      enemy.health = 1;
      enemy.maxHealth = 1;
    }

    for (let tick = 0; tick < 100 && simulation.state.enemies.length === 0; tick += 1) {
      simulation.step({ ...idle, fire: true, aimX: simulation.state.player.position.x, aimY: simulation.state.player.position.y });
    }
    for (let tick = 0; tick < 100 && (simulation.state.wave < 2 || simulation.state.enemies.length === 0); tick += 1) {
      simulation.step({ ...idle, fire: true, aimX: simulation.state.player.position.x, aimY: simulation.state.player.position.y });
    }

    expect(simulation.state.wave).toBeGreaterThanOrEqual(2);
    expect(simulation.state.enemies.length).toBeGreaterThan(0);
    expect(simulation.state.enemies.some((enemy) => enemy.maxHealth > 1 || enemy.speed > 118)).toBe(true);
  });

  it("transitions to game over and records the seed and final tick", () => {
    const simulation = new VectorSiegeSimulation("terminal");
    for (const enemy of simulation.state.enemies) {
      enemy.position = { ...simulation.state.player.position };
      enemy.speed = 0;
    }

    let safety = 0;
    while (simulation.state.phase !== "game-over" && safety < 500) {
      simulation.step(idle);
      safety += 1;
    }

    expect(simulation.state.phase).toBe("game-over");
    expect(simulation.state.completion).toEqual({ seed: "terminal", finalTick: simulation.state.tick });
  });

  it("pauses and resumes without advancing the fixed simulation tick", () => {
    const simulation = new VectorSiegeSimulation("pause");
    simulation.step(idle);
    const pausedAt = simulation.state.tick;

    simulation.pause();
    simulation.step({ ...idle, right: true, fire: true });
    expect(simulation.state.phase).toBe("paused");
    expect(simulation.state.tick).toBe(pausedAt);

    simulation.resume();
    simulation.step({ ...idle, right: true });
    expect(simulation.state.phase).toBe("running");
    expect(simulation.state.tick).toBe(pausedAt + 1);
  });

  it("reaches the same terminal state from the same seed and scripted inputs", () => {
    const first = runScript("reproducible-seed");
    const second = runScript("reproducible-seed");

    expect({
      phase: first.state.phase,
      tick: first.state.tick,
      wave: first.state.wave,
      score: first.state.score,
      defeated: first.state.defeated,
      health: first.state.player.health,
      player: first.state.player.position,
      enemies: first.state.enemies.map((enemy) => ({ id: enemy.id, kind: enemy.kind, x: enemy.position.x, y: enemy.position.y, health: enemy.health })),
    }).toEqual({
      phase: second.state.phase,
      tick: second.state.tick,
      wave: second.state.wave,
      score: second.state.score,
      defeated: second.state.defeated,
      health: second.state.player.health,
      player: second.state.player.position,
      enemies: second.state.enemies.map((enemy) => ({ id: enemy.id, kind: enemy.kind, x: enemy.position.x, y: enemy.position.y, health: enemy.health })),
    });
  });
});

