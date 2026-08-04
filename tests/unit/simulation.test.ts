import { describe, expect, it } from "vitest";

import {
  FIXED_TIMESTEP,
  createDeterministicRandom,
  createSimulation,
  type GameState,
  type InputFrame,
} from "../../src/shared-simulation/simulation";

function tick(simulation: ReturnType<typeof createSimulation>, frames: number, input: InputFrame = {}): void {
  for (let index = 0; index < frames; index += 1) simulation.step(input);
}

function fireAt(simulation: ReturnType<typeof createSimulation>, target: { x: number; y: number }): boolean {
  simulation.step({ aim: target, fire: true });
  let defeatedOnFireTick = simulation.state.events.some((event) => event.type === "enemy-defeated");
  // The default cooldown is eight fixed ticks.  Let the projectile reach a
  // nearby fixture without relying on a renderer or a wall-clock delay.
  for (let index = 0; index < 12; index += 1) {
    simulation.step({ aim: target });
    defeatedOnFireTick = defeatedOnFireTick || simulation.state.events.some((event) => event.type === "enemy-defeated");
  }
  return defeatedOnFireTick;
}

function comparableState(state: GameState): unknown {
  return {
    phase: state.phase,
    seed: state.seed,
    tick: state.tick,
    score: state.score,
    wave: state.wave,
    waveDifficulty: state.waveDifficulty,
    player: state.player,
    enemies: state.enemies,
    projectiles: state.projectiles,
    completedGame: state.completedGame,
  };
}

describe("deterministic random source", () => {
  it("produces the same sequence for the same seed", () => {
    const left = createDeterministicRandom("stage-one");
    const right = createDeterministicRandom("stage-one");

    expect(Array.from({ length: 8 }, () => left.next())).toEqual(
      Array.from({ length: 8 }, () => right.next()),
    );
    expect(left.nextInt(10)).toBeGreaterThanOrEqual(0);
    expect(left.nextInt(10)).toBeLessThan(10);
  });
});

describe("Vector Siege simulation", () => {
  it("starts in the menu and moves with normalized axes inside arena bounds", () => {
    const simulation = createSimulation({
      seed: 7,
      arena: { width: 200, height: 140 },
      spawnRadius: 40,
    });
    expect(simulation.state.phase).toBe("menu");
    simulation.start();
    const start = { ...simulation.state.player.position };

    simulation.step({ moveX: 1, moveY: 1 });
    const moved = simulation.state.player.position;
    const distanceMoved = Math.hypot(moved.x - start.x, moved.y - start.y);
    expect(distanceMoved).toBeCloseTo(250 * FIXED_TIMESTEP, 8);
    expect(moved.x).toBeGreaterThan(start.x);
    expect(moved.y).toBeGreaterThan(start.y);

    tick(simulation, 200, { moveX: 1, moveY: 1 });
    expect(simulation.state.player.position.x).toBeLessThanOrEqual(200 - simulation.state.player.radius);
    expect(simulation.state.player.position.y).toBeLessThanOrEqual(140 - simulation.state.player.radius);
  });

  it("spawns generated enemies outside the configured radius and exposes distinct variants", () => {
    const simulation = createSimulation({ seed: 21, spawnRadius: 250 });
    simulation.start();
    const player = simulation.state.player.position;
    const distances = simulation.state.enemies.map((enemy) => Math.hypot(
      enemy.position.x - player.x,
      enemy.position.y - player.y,
    ));

    expect(distances.every((distance) => distance >= 250)).toBe(true);
    expect(simulation.state.enemies.map((enemy) => enemy.kind)).toContain("chaser");
    expect(simulation.state.enemies.map((enemy) => enemy.kind)).toContain("striker");
    expect(simulation.state.enemies.find((enemy) => enemy.kind === "striker")?.speed).toBeLessThan(
      simulation.state.enemies.find((enemy) => enemy.kind === "chaser")?.speed ?? 0,
    );
  });

  it("fires a projectile, collides with an enemy, and awards score", () => {
    const simulation = createSimulation({
      seed: 3,
      baseEnemyCount: 1,
      initialEnemies: [{ kind: "chaser", position: { x: 700, y: 360 } }],
    });
    simulation.start();
    const enemyId = simulation.state.enemies[0].id;
    const defeatedOnFireTick = fireAt(simulation, { x: 700, y: 360 });

    expect(simulation.state.score).toBe(100);
    expect(simulation.state.enemies.some((enemy) => enemy.id === enemyId)).toBe(false);
    expect(defeatedOnFireTick).toBe(true);
  });

  it("applies contact damage once during invulnerability and records a game over", () => {
    const simulation = createSimulation({
      seed: 8,
      playerMaxHealth: 2,
      invulnerabilityTicks: 5,
      baseEnemyCount: 1,
      initialEnemies: [{ kind: "chaser", position: { x: 640, y: 360 } }],
    });
    simulation.start();

    simulation.step();
    expect(simulation.state.player.health).toBe(1);
    expect(simulation.state.player.isInvulnerable).toBe(true);
    tick(simulation, 3);
    expect(simulation.state.player.health).toBe(1);

    tick(simulation, 3);
    expect(simulation.state.player.health).toBe(0);
    expect(simulation.state.phase).toBe("game-over");
    expect(simulation.state.completedGame).toEqual({ seed: 8, finalTick: 6 });
  });

  it("progresses waves deterministically and increases difficulty", () => {
    const simulation = createSimulation({
      seed: 13,
      baseEnemyCount: 1,
      enemyCountIncrement: 1,
      initialEnemies: [{ kind: "chaser", position: { x: 700, y: 360 } }],
    });
    simulation.start();
    const firstWaveEnemy = simulation.state.enemies[0];
    expect(simulation.state.wave).toBe(1);
    fireAt(simulation, firstWaveEnemy.position);

    expect(simulation.state.wave).toBe(2);
    expect(simulation.state.enemies).toHaveLength(2);
    const waveTwoChaser = simulation.state.enemies.find((enemy) => enemy.kind === "chaser");
    expect(waveTwoChaser?.maxHealth).toBeGreaterThan(firstWaveEnemy.maxHealth);
    expect(waveTwoChaser?.speed).toBeGreaterThan(firstWaveEnemy.speed);
    expect(simulation.state.waveDifficulty).toBeCloseTo(1.15);
  });

  it("supports pause/resume and restart without advancing paused ticks", () => {
    const simulation = createSimulation({ seed: 34, baseEnemyCount: 1 });
    simulation.start();
    simulation.step();
    const tickBeforePause = simulation.state.tick;

    simulation.pause();
    simulation.step({ moveX: 1, fire: true });
    expect(simulation.state.phase).toBe("paused");
    expect(simulation.state.tick).toBe(tickBeforePause);

    simulation.resume();
    simulation.step();
    expect(simulation.state.phase).toBe("running");
    expect(simulation.state.tick).toBe(tickBeforePause + 1);

    simulation.restart();
    expect(simulation.state.phase).toBe("running");
    expect(simulation.state.tick).toBe(0);
    expect(simulation.state.wave).toBe(1);
    expect(simulation.state.score).toBe(0);
  });

  it("reaches the same terminal state for the same seed and scripted inputs", () => {
    const run = (): GameState => {
      const simulation = createSimulation({
        seed: 90210,
        playerMaxHealth: 1,
        baseEnemyCount: 1,
        initialEnemies: [{ kind: "chaser", position: { x: 640, y: 360 } }],
      });
      simulation.start();
      const inputs: InputFrame[] = [
        { moveX: 1, aim: { x: 900, y: 360 }, fire: true },
        { moveY: -1, aim: { x: 900, y: 200 } },
        { moveX: -1 },
        {},
        {},
      ];
      for (const input of inputs) simulation.step(input);
      return simulation.state;
    };

    const left = run();
    const right = run();
    expect(comparableState(left)).toEqual(comparableState(right));
    expect(left.completedGame?.seed).toBe(90210);
    expect(left.completedGame?.finalTick).toBe(left.tick);
  });
});
