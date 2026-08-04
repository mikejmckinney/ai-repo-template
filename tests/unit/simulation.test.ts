import { describe, expect, it } from "vitest";
import {
  type InputFrame,
  VectorSiegeSimulation,
} from "../../src/shared-simulation/simulation";

const idle: InputFrame = {
  up: false,
  down: false,
  left: false,
  right: false,
  fire: false,
  aimX: 640,
  aimY: 360,
};

function runningSimulation(seed = 0x51e697e): VectorSiegeSimulation {
  const simulation = new VectorSiegeSimulation(seed);
  simulation.start();
  return simulation;
}

function stepUntil(
  simulation: VectorSiegeSimulation,
  predicate: () => boolean,
  input: InputFrame = idle,
  maximumTicks = 600,
): void {
  for (let tick = 0; tick < maximumTicks && !predicate(); tick += 1) {
    simulation.step(input);
  }
}

describe("VectorSiegeSimulation", () => {
  it("moves with normalized input and clamps the player to the arena", () => {
    const simulation = runningSimulation();
    const startX = simulation.state.player.x;

    for (let tick = 0; tick < 30; tick += 1) {
      simulation.step({ ...idle, right: true, down: true });
    }

    expect(simulation.state.player.x).toBeGreaterThan(startX);
    expect(simulation.state.player.y).toBeGreaterThan(simulation.config.height / 2);

    for (let tick = 0; tick < 900; tick += 1) {
      simulation.step({ ...idle, right: true, down: true });
    }

    expect(simulation.state.player.x).toBeLessThanOrEqual(
      simulation.config.width - simulation.config.arenaPadding - simulation.state.player.radius,
    );
    expect(simulation.state.player.y).toBeLessThanOrEqual(
      simulation.config.height - simulation.config.arenaPadding - simulation.state.player.radius,
    );
  });

  it("damages an enemy once per projectile and awards score on defeat", () => {
    const simulation = runningSimulation();
    simulation.clearEnemies();
    const enemy = simulation.addEnemy("chaser", simulation.state.player.x + 180, simulation.state.player.y);
    const firstScore = simulation.state.score;

    stepUntil(
      simulation,
      () => simulation.state.score > firstScore,
      { ...idle, aimX: enemy.x, aimY: enemy.y, fire: true },
    );

    expect(simulation.state.score).toBeGreaterThan(firstScore);
    expect(simulation.state.wave).toBeGreaterThan(1);
    expect(simulation.state.enemies.length).toBeGreaterThan(0);
    expect(simulation.lastEvents.some((event) => event.type === "enemy-defeated")).toBe(true);
  });

  it("applies contact damage and respects the invulnerability window", () => {
    const simulation = runningSimulation();
    simulation.clearEnemies();
    simulation.addEnemy("chaser", simulation.state.player.x, simulation.state.player.y);

    simulation.step(idle);
    const healthAfterHit = simulation.state.player.health;
    expect(healthAfterHit).toBe(simulation.state.player.maxHealth - 1);
    expect(simulation.state.player.invulnerableTicks).toBeGreaterThan(0);

    for (let tick = 0; tick < 10; tick += 1) {
      simulation.step(idle);
    }

    expect(simulation.state.player.health).toBe(healthAfterHit);
  });

  it("advances waves deterministically after a clear", () => {
    const simulation = runningSimulation();
    const firstWave = simulation.state.wave;
    simulation.clearEnemies();

    const result = simulation.step(idle);

    expect(simulation.state.wave).toBe(firstWave + 1);
    expect(simulation.state.enemies.length).toBeGreaterThan(0);
    expect(result.events.some((event) => event.type === "wave-started")).toBe(true);
    expect(new Set(simulation.state.enemies.map((enemy) => enemy.kind))).toEqual(new Set(["chaser", "tank", "striker"]));
    for (const enemy of simulation.state.enemies) {
      const distance = Math.hypot(enemy.x - simulation.state.player.x, enemy.y - simulation.state.player.y);
      expect(distance).toBeGreaterThanOrEqual(simulation.config.spawnRadius);
    }
  });

  it("reaches the same terminal state for the same seed and scripted inputs", () => {
    const script = (simulation: VectorSiegeSimulation): void => {
      simulation.clearEnemies();
      simulation.addEnemy("chaser", simulation.state.player.x, simulation.state.player.y);
      simulation.addEnemy("tank", simulation.state.player.x, simulation.state.player.y);
      simulation.addEnemy("striker", simulation.state.player.x, simulation.state.player.y);
      simulation.step(idle);
    };

    const left = new VectorSiegeSimulation(123456, { invulnerabilityTicks: 0 });
    const right = new VectorSiegeSimulation(123456, { invulnerabilityTicks: 0 });
    left.start();
    right.start();
    script(left);
    script(right);

    expect(left.state.status).toBe("gameover");
    expect(right.snapshot()).toEqual(left.snapshot());
  });

  it("records the seed and final simulation tick when a run ends", () => {
    const simulation = runningSimulation(98765);
    simulation.clearEnemies();
    simulation.addEnemy("chaser", simulation.state.player.x, simulation.state.player.y);

    for (let tick = 0; tick < simulation.state.player.maxHealth + 2; tick += 1) {
      simulation.step(idle);
      for (let invulnerability = 0; invulnerability < 100; invulnerability += 1) {
        simulation.step(idle);
      }
    }

    expect(simulation.state.status).toBe("gameover");
    expect(simulation.state.completionRecord).toMatchObject({ seed: 98765 });
    expect(simulation.state.completionRecord?.finalTick).toBe(simulation.state.tick);
  });
});
