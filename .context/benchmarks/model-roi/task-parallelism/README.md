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

This operator check requires the frozen commit locally and verifies its branch
against `origin`. Repository-copy checks use the runner's `--validate-state
--offline` structural mode instead; that mode reports whether the frozen commit
was also available for local task-blob verification and never claims remote
identity.

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

### Retained-Branch Diagnostic

The post-pilot diagnostic evaluates retained candidate branches without changing
official scores or creating confirmatory evidence:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-diagnostic-validate
```

Eight candidates produced work, and all eight final reports identified sandbox
restrictions on browser installation, process launch, or local TCP binding. The
parent evaluator scored all produced branches outside the candidate sandbox. The
tracked point observation records three parent E2E passes, including one Arm A
branch whose E2E result changed across diagnostic passes. Therefore diagnostic
quality totals are not comparative or adoption evidence. Stable observations are:

- the official pilot scores remain unchanged;
- three Arm A branches officially scored zero despite passing install, unit, and
  build checks in the parent evaluator;
- run 002, the only officially completed Arm B run, declined fan-out;
- the original candidate sandbox prevented reliable browser or server checks;
- candidate-authored E2E behavior is not stable enough to act as the sole parent
  acceptance journey.

### Revised Feasibility Boundary

The blocked revision uses one sequential assignment per arm. Candidate timeout,
partial, or failed outcomes count as the arm result. Only a verified provider or
harness-invalid attempt may receive one replacement. Both candidates use normal
Codespace permissions and run build, unit, and browser checks with Playwright or
Chrome DevTools; the parent evaluator independently evaluates every branch that
produced work regardless of the candidate self-report.

The non-executing planner computes deterministic digests for the two candidate
instruction bodies. Activation renders the selected body as root
`AGENTS.override.md` from the repository's normal guidance. Arm A replaces the
execution-model paragraph with the monolithic treatment. Arm B replaces it with
instruction to use as many native subagents as needed and integrate their work.
Both bodies replace the repository entry gate with benchmark-local orientation
and mark GitHub-only branch, PR, advisory-label, and live-state duties as inert
in the evaluator-owned checkout; all other applicable repository policy remains.
Codex discovers the override before `AGENTS.md` at project scope, as
documented in the
[Codex instruction guide](https://developers.openai.com/codex/agent-configuration/agents-md).

The plan requires a standalone temporary clone rather than a shared Git worktree,
so normal Git commands cannot read prior candidate refs through the control
repository's object database. Candidate execution uses explicit
`--sandbox danger-full-access`; network, browser, localhost, and shell access
remain available. This PR does not add a revision execution state or parameterize
the completed pilot runner. Those mutations occur only after separate execution
approval, when the planner contract is activated. Activation must also use a
revision-specific candidate-report schema whose `worker_count` permits the
uncapped Arm B treatment; the completed pilot's v1 report schema remains frozen.

```bash
make -C scripts/benchmark/task-parallelism phase-0b-revision-validate
make -C scripts/benchmark/task-parallelism phase-0b-revision-plan
```

The rendered preparation plan remains the immutable blocked A/B contract. The
maintainer separately approved activation and exactly one Arm A assignment
followed by one Arm B assignment on 2026-08-05. After both completed, the
maintainer authorized one prompt-gated Arm C assignment in the same PR. Arm C
must autonomously create and self-check a dependency, shared-contract, write-set,
validation, and integration work graph before using native subagents. It does not
use the deferred deterministic external gate. Validate the approved state with:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-revision-execution-validate
```

The activation runner creates a standalone `--no-local --single-branch` clone
for each attempt, disables its upstream URL before candidate execution, injects
the arm-specific `AGENTS.override.md`, and removes that evaluator-owned file
before snapshotting candidate work. Raw Codex output and temporary clones remain
under ignored `.artifacts/`; bounded candidate reports, attempt records, process
metadata, evaluator results, evaluator transcripts, and the directional summary live
under tracked `results/phase-0b-revision/`.

After the activation implementation SHA is frozen, execute only in this order:

```bash
python3 scripts/benchmark/task-parallelism/run-phase-0b-revision.py \
  --run-id vs-p0b-next-a
python3 scripts/benchmark/task-parallelism/run-phase-0b-revision.py \
  --run-id vs-p0b-next-b
python3 scripts/benchmark/task-parallelism/run-phase-0b-revision.py \
  --run-id vs-p0b-next-c
make -C scripts/benchmark/task-parallelism phase-0b-revision-summary
```

A candidate timeout, partial completion, failure, or low-quality result is
terminal. The prior A/B authorization allowed one verified provider-transient or
harness-invalid replacement; Arm C authorizes no replacement. Every original
attempt remains retained, and the parent evaluator runs for every checkout that
produced work. The resulting three-arm comparison is directional feasibility
evidence only: it does not modify the official pilot scores, supply confirmatory
evidence, or support an adoption claim. Codex emits one aggregate usage record
for a candidate turn, so the summary reports per-arm aggregate tokens and marks
parent/worker token splitting unavailable.

Each result labels its wall-clock scope. The retained A/B/C runs were captured
with `runner-integrated` timing, which includes candidate execution, evaluation,
snapshot, and publication once; their candidate-only duration is unavailable.
Future runs capture `candidate-only` timing immediately after the model process
and add evaluator time once for the integrated comparison. Missing candidate
self-report leaves the entire self-reported telemetry block null while process
metadata and the summary retain harness-observed native spawn calls. Null means
unavailable, not a measured zero.

The summary calculates each candidate arm against monolithic Arm A. Equivalent
API cost uses the official `gpt-5.6-luna` standard rates published at
<https://developers.openai.com/api/docs/models/gpt-5.6-luna>. Because retained
usage does not identify per-request context bands, it reports both the short-rate
estimate and an all-long-context upper bound. Each comparison includes quality
and integrated-time ratios, speedup, parallel efficiency, cost ratio, quality per
dollar/hour, and 50/50, 75/25, and 25/75 cost/time ROI sensitivity.
When a timed-out process emits no terminal usage event, equivalent cost and cost
ratio remain unavailable rather than treating zero retained tokens as zero spend.

If the runner process exits after recording an in-progress attempt but before
its terminal state, first confirm that no candidate or evaluator process remains,
then recover the retained checkout and artifacts with:

```bash
python3 scripts/benchmark/task-parallelism/run-phase-0b-revision.py \
  --recover-interrupted <attempt-id>
```

The recovery path reconstructs already-complete terminal evidence when present.
Otherwise it snapshots and evaluates produced work, classifies the attempt as a
harness interruption, and applies the existing one-replacement budget. It never
starts a second candidate process by itself. Because the original candidate
process duration is unavailable after interruption, the recovered result records
zero candidate wall-clock seconds and keeps elapsed operator time only in process
metadata. The result and summary mark that duration non-comparable rather than
summing it as measured runtime. Recovery records a missing or modified override
as not intact when the checkout remains available, unless the harness wrote a
successful verification to a harness-owned integrity record under ignored
`.artifacts/` before removing that file. This transient record is deleted once
terminal state is recorded and is not part of the final retained evidence.
Recovery records integrity as unknown when no checkout remains. A failed
publication is retained as terminal harness evidence instead of rerunning
evaluation.

## Phase 0C Transport Apparatus

Issue #581 adds the isolated `phase-0c-transport/` namespace without changing
the completed Phase 0B manifests, schemas, runners, or results. Direct
requirements live in `requirements.in`; `requirements.txt` is the hashed
transitive lock compiled by `uv 0.11.29` for Python 3.12. Reproduce and install
it with:

```bash
uv venv --python 3.12 .artifacts/task-parallelism/phase-0c-venv
uv pip compile --python-version 3.12 --generate-hashes \
  scripts/benchmark/task-parallelism/requirements.in \
  --output-file scripts/benchmark/task-parallelism/requirements.txt
uv pip install \
  --python .artifacts/task-parallelism/phase-0c-venv/bin/python \
  --require-hashes \
  --requirement scripts/benchmark/task-parallelism/requirements.txt
PATH="$PWD/.artifacts/task-parallelism/phase-0c-venv/bin:$PATH" \
  make -C scripts/benchmark/task-parallelism phase-0c-validate
PATH="$PWD/.artifacts/task-parallelism/phase-0c-venv/bin:$PATH" \
  make -C scripts/benchmark/task-parallelism phase-0c-preflight
PATH="$PWD/.artifacts/task-parallelism/phase-0c-venv/bin:$PATH" \
  bats --tap scripts/tests/task-parallelism-phase-0c-gate.bats \
  scripts/tests/task-parallelism-phase-0c-transport.bats
jq '{status, candidate_processes_started, preflight_fixture_graph_decision,
  a2a, canonical_payload_echo_equivalent, duplicate_events_suppressed,
  future_paid_topology_limit}' \
  .artifacts/task-parallelism/phase-0c-preflight.json
```

The preflight fixture gate deterministically evaluates seven predicates: independently testable
outcomes; complete transitive dependencies; parent-owned frozen contracts;
normalized repo-relative POSIX write paths with prefix overlap detection or
dependency sequencing; child and integration validation; substantive-work
justification of at least 15 minutes per node; and concurrency cap two. It
rejects absolute, traversal, glob, empty, and dot paths. Its output has no
timestamps. Rejection returns before a child callback, and accepted overlapping
writes are placed in separate dependency waves.

The local fixture reader loads bounded canonical payloads without transport or
GitHub behavior. The live side uses A2A protocol `1.0` from specification release
`1.0.0` through `a2a-sdk==1.1.2`, a separate loopback-only HTTP process,
JSON-RPC, standard `/.well-known/agent-card.json` discovery, and structured
non-streaming direct `Message` responses. Server middleware rejects POSTs unless
`A2A-Version: 1.0` is present and records the validated value. The resulting
claim is only that standard discovery and structured canonical-payload echo
succeeded. It is not evidence of production-shaped GitHub/A2A transport
equivalence, A2A task lifecycle, production authentication/security, streaming,
deployment, or broad protocol conformance.

The C/D treatment files are preflight fixtures only. Their causal-freeze check
requires fixture graph, fixture gate, fixture prompt, runtime, model, topology,
timeout, and evaluator bytes to match and permits only `transport.backend` and
`transport.backend_evidence` to differ. They cannot be cited as a paid planner
graph, gate, or treatment freeze.

**Paid approval stop:** passing either target authorizes no model process. Before
any paid run, a separate execution PR must add real GitHub and A2A adapters, task
lifecycle, child/process/result and matched-summary schemas, and persisted keyed
state with issue #581's immutable-key/idempotent-retry semantics. Its approved
planner output and deterministic gate report must be separate execution records,
frozen before arm order is selected; this fixture and its digests cannot satisfy
that requirement. Explicit approval must name that future freeze and the maximum
topology limit: one shared planner plus four processes per arm (one parent
implementer, at most two writable children, then one integration process), nine
total across one sequential C/D pair, at most three simultaneous processes, 45
minutes end-to-end per arm, and zero candidate-defect replacements.
