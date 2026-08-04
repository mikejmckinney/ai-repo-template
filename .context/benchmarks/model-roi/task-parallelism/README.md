# Task-Parallelism Benchmark Preparation

Phase 0A is the deterministic, no-spend readiness boundary for issue #545. It
validates the tracked Vector Siege campaign record and exact placeholder assets;
it does not execute candidates or authorize Phase 0B.

## Contract

- `campaign.phase-0a.json` is the only production campaign input. Files under
  `scripts/benchmark/task-parallelism/fixtures/` are test-only and cannot replace
  it through the argument-free Make target.
- Both schemas declare JSON Schema Draft 2020-12 and validation requires exactly
  `jsonschema==4.26.0`. Preflight never installs dependencies.
- Placeholder MP3, WAV, WebP, palette, atlas, and manifest files are generated
  locally from `assets/source/primitives.json` with FFmpeg `6.1.1-3ubuntu5`.
- `make -C scripts/benchmark/task-parallelism preflight` clears the environment,
  enters a user and network namespace with `unshare -Urn`, installs a Python
  audit hook for the named socket and child-process paths, and validates only
  local tracked files.

This is bounded validator isolation, not a hostile-code sandbox. Unsupported
hosts and version mismatches fail closed.

## Commands

```bash
make -C scripts/benchmark/task-parallelism assets-check
make -C scripts/benchmark/task-parallelism preflight
jq '{status, campaign, freeze_state, assets, isolation, phase_0b}' \
  .artifacts/task-parallelism/preflight-report.json
bats --tap scripts/tests/task-parallelism-preflight.bats
```

The report contains names, booleans, counts, and checksums only. Provider
credential values are neither inherited nor emitted.

## Approval Boundary

Passing Phase 0A means the local apparatus is reproducible and fail-closed. It
does not approve candidate invocations, paid generation, network access,
Cloudflare changes, deployment, publication, A2A, portability tests, or an
ADR-031 policy change. Phase 0B requires a separate explicit maintainer approval.

## Phase 0B Preparation

The tracked Phase 0B preparation contract freezes the candidate runtime,
scaffold, prompts, ten-run order, retry limits, and Gate 0 thresholds without
creating a candidate worktree or starting Codex:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-validate
make -C scripts/benchmark/task-parallelism phase-0b-plan
jq '{execution_status, candidate_processes_started, assignments, gate_0}' \
  .artifacts/task-parallelism/phase-0b-run-plan.json
bats --tap scripts/tests/task-parallelism-phase-0b.bats
```

Three completed Codex contexts verified `gpt-5.6-luna` with reasoning effort
`max` on `codex-cli 0.146.0`; the bounded evidence record is under `evidence/`.
The candidate command repeats model and effort explicitly and overrides the
repository default with `--sandbox workspace-write`.

The frozen scaffold uses Node 24.14.0, npm 11.9.0, Phaser 4.2.1, Vite 8.2.0,
TypeScript 7.0.2, Vitest 4.1.10, Playwright 1.62.1, and Node types 26.1.2. It
retains empty game, shared-simulation, API, migration, evaluator-visible asset,
unit-test, and end-to-end-test surfaces. Its package lock and every tracked
source/configuration file are hash-checked before a run plan is emitted.

The preparation manifest remains `execution.status: blocked`. A later approval
must create and record the frozen base before any of the five Arm A and five Arm
B assignments can execute. This preparation approval does not authorize those
candidate runs.

## Phase 0B Execution

The maintainer approved the ten-run pilot on 2026-08-04. The separate execution
state records that authorization while preserving the preparation manifest as a
blocked, immutable freeze. Validate current progress with:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-execution-validate
```

Candidate processes start only through an explicit run identifier:

```bash
python3 scripts/benchmark/task-parallelism/run-phase-0b.py \
  --run-id vs-p0b-001
```

The runner enforces frozen-base and task-blob identity, sequential assignment
order, the exact Luna/max command, a credential-stripped candidate environment,
schema-backed self-report and result telemetry, and one remote evidence branch
per attempt. Candidate defects receive no retry. One verified provider or
harness failure may consume the campaign's single retry; the original attempt,
elapsed time, and telemetry remain under `results/phase-0b/attempts/`. After all
ten assignments have terminal results, derive the Gate 0 input:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-summary
python3 scripts/benchmark/task-parallelism/prepare-phase-0b.py \
  --evaluate-gate \
  .context/benchmarks/model-roi/task-parallelism/results/phase-0b-summary.json
```

The preregistered objective feasibility score awards 10 points for a completed
Codex turn, 10 for produced work, 10 for dependency installation, 20 for unit
tests, 20 for the production build, and 30 for the Playwright journey. This
lower-bound score is not blind product-quality grading and cannot support an
adoption claim. The evaluator installs the lockfile's Chromium build before the
Playwright journey so browser-cache state cannot change the score.

### Phase 0B Pilot Outcome

The approved pilot completed all ten assignments from the frozen base. Gate 0
is a no-go:

- 10 of 10 assignments reached a terminal state and required telemetry is
  schema-complete for every assignment. Candidate-measured coordination
  telemetry is retained for 8 assignments; runs 001 and 005 timed out without a
  final self-report and therefore retain explicit zero-filled fallback fields.
- 1 assignment completed, 8 were candidate failures, and 1 was a harness
  failure under intention-to-treat scoring.
- Arm A recorded 0 total quality points across 5 runs. Arm B recorded 100 total
  quality points across 5 runs; its one completed candidate passed install,
  unit, build, and parent-evaluator Playwright checks.
- Arm B recorded 2 fan-out elections, meeting that Gate 0 threshold.
- Harness reliability was 9 of 11 retained attempts, or 81.8%, below the 90%
  threshold. The original schema-rejection attempt and the later timeout
  evidence-loss failure are both retained.
- Final assignment records total 15,289 wall-clock seconds. The original
  18-second harness-failed attempt is additional retained attempt time.
- Recomputed diffs from every published candidate branch show zero writes to
  `.agents/`, `TASK.md`, or supplied benchmark assets, matching all tracked
  `predicted_path_drift_count` values.

The result does not support an adoption claim or confirmatory campaign. The
observed data instead require harness revision before another feasibility run.
