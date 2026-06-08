# Model ROI Benchmark Protocol

> Durable protocol surface for the model ROI benchmark tracked in issue `#374`.
> The benchmark-specific prompt lives at `.github/prompts/model-roi-benchmark-candidate.md`.
> The current execution direction lives under `scripts/benchmark/`.
> Repeatable operator steps live in [`benchmark-runbook.md`](./benchmark-runbook.md).
> Current scored results live in [`results/agent-roi-benchmark-results.md`](./results/agent-roi-benchmark-results.md).

## Status

- **Completed benchmark record:** monolithic Stage 1, extended Stage 1, Stage 1C context injection, Stage 1D duo planner/implementer, and issue #376 orchestration pipeline runs.
- **Primary decision metric:** marginal ROI, computed as `score / marginal cost USD`.
- **Stage 1 effort policy:** target `medium` where selectable; use platform default only where no effort control exists and record the caveat.
- **Manual fallback:** allowed after a documented headless failure via `make worktree` followed by `make record`; direct GUI agents such as Antigravity need explicit manual-capture evidence.

## Companion surfaces

Benchmark prompts and benchmark tasks intentionally live in different places.
Prompts are reusable **execution wrappers**: they define how an agent should run
the benchmark. Task files are benchmark **payloads**: they define what work the
agent must perform, plus sealed reference metadata for evaluators.

| Path | Purpose |
|---|---|
| `.github/prompts/model-roi-benchmark-candidate.md` | Canonical prompt body reused unchanged across candidates. Candidate-specific input is limited to the run-metadata block and injected task. |
| `.github/prompts/model-roi-duo-planner.md` | Stage 1D planner-phase prompt; creates the plan artifact only. |
| `.github/prompts/model-roi-duo-implementer.md` | Stage 1D implementer-phase prompt; consumes the plan artifact and produces the scored diff. |
| `.github/prompts/model-roi-orchestration-pipeline-candidate.md` | Issue #376 pipeline prompt; enables subagents/handoffs while keeping runner-owned push/PR creation. |
| `.context/benchmarks/model-roi/benchmark-runbook.md` | Repeatable setup, run, grading, telemetry, and known-issues procedure for future benchmark sessions. |
| `.context/benchmarks/model-roi/stage-1d-duo-workflow.md` | Stage 1D planner/implementer experiment protocol, candidates, cost view, and commands. |
| `.context/benchmarks/model-roi/issue-376-orchestration-pipeline.md` | Pipeline experiment protocol, candidate set, overlay policy, and grading notes for issue #376. |
| `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md` | Current scored benchmark record, cost source register, and ROI tables used to justify repo-local ROI/performance revisions. |
| `.context/benchmarks/model-roi/tasks/` | Maintainer-authored task specs. Each file has candidate-safe task text plus sealed reference metadata. |
| `scripts/benchmark/Makefile` | Current operator entrypoint for `base`, `run`, `suite`, `duo-run`, `duo-suite`, `worktree`, `record`, `collect`, `unseal`, and `grade-*` targets. |
| `.context/benchmarks/model-roi/grading/` | Canonical rubric (`rubric.v1`, `rubric.pipeline.v1`), JSON schemas, task grading specs, and score-set comparability rules. |
| `scripts/benchmark/regrade-stage.sh` | Unified canonical regrade driver for stages `1`, `1c`, `1d`, `pipeline`, `1e` (`prepare`, `grade`, `record`, `compile`, `status`). |
| `scripts/benchmark/llm_grade_subjective.py` | True LLM blind grader: feeds each bundle's `subjective-prompt.md` to Cursor agent (`model-roi-grader-v1`). |
| `scripts/benchmark/update-benchmark-results.py` | Sync `results/agent-roi-benchmark-results.md` (`scores`, `roi`, `sort`, `all`). |
| `scripts/benchmark/stage-llm-responses-v1/` | Recorded subjective JSON for `cursor-llm-blind-v1` regrades (Stage 1C / 1D / pipeline). |
| `scripts/benchmark/stage-1-llm-responses-v1/` | Stage 1 monolithic LLM responses (separate dir — shares task ids with 1D). |
| `scripts/benchmark/stage-1e-llm-responses-v1/` | Stage 1E CP-1 LLM responses (`cursor-llm-blind-v1`, one JSON per run_group/eval). |
| `scripts/benchmark/regrade-stage-1e.sh` | Operator script: prepare/record/compile canonical regrades for all Stage 1E CP-1 `RUN_GROUP`s. |
| `.github/prompts/model-roi-grader-v1.md` | Locked subjective grader prompt (JSON-only output). |
| `scripts/benchmark/candidates.tsv.example` | Example sealed alias manifest for Core Stage 1 plus later-phase placeholders. |
| `scripts/benchmark/duo-candidates.tsv.example` | Example sealed alias manifest for Stage 1D planner/implementer candidates. |
| `scripts/benchmark/orchestration-candidates.tsv.example` | Example sealed alias manifest for issue #376 pipeline candidates. |
| `.context/benchmarks/model-roi/context-packs/` | Stage 1E targeted context-pack manifests (`<pack-id>.tsv`). |
| `.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example` | Example manifest for CP-1 pack screen (`ctx-cur`, `ctx-gem`). |
| `.context/benchmarks/model-roi/stage-1e-pack-robustness-candidates.tsv.example` | Example manifest for CP-2 robustness check. |
| `.context/benchmarks/model-roi/result-template.md` | Per-alias run record with blind-safe and sealed sections. |
| `.context/benchmarks/model-roi/summary-template.md` | Task-level Stage 1 summary and shortlist template. |

## Core Stage 1 Contract

Core Stage 1 exists to produce a **blind, auditable screen** from a frozen base
branch and a single prompt body shared across aliased candidates. Later
experiments reuse the same artifact model but vary context injection,
orchestration, or planner/implementer workflow shape.

Required behavior:

1. Reuse the same prompt body for every candidate run.
2. Inject exactly one concrete task from `.context/benchmarks/model-roi/tasks/<task-id>.md`.
3. Keep candidate branches and grader-facing artifacts aliased.
4. Keep each stage/variant explicit in its task id, manifest, and results section.
5. Keep Stage 1 effort fixed at `medium` where the harness can set it; Cursor remains `medium (requested)`.
6. Record manual fallback explicitly when a bundled adapter fails headlessly.
7. Defer new task classes, new effort sweeps, or model-routing remap decisions to an explicit new benchmark plan.

## Task selection

Issue #374 requires tasks to come from closed issues with merged reference PRs. The candidate prompt stays task-agnostic; the runner renders a per-run prompt by injecting only the candidate-safe `## Candidate task` section from the task file. Reference issue/PR/merge SHA metadata remains in the task file for evaluator use and must not be included in the candidate prompt.

Committed Phase A task specs:

| Task id | Class | Source issue | Reference PR | Reference merge SHA |
|---|---|---:|---:|---|
| `opfit-281-class-a` | A — operational fit | #281 | #288 | `e8f5f96c44568a32e40ce1995b9ffb80c0009d28` |
| `opfit-326-class-b` | B — reasoning / code | #326 | #358 | `f3145229b2ad8044519ed1c1f88b5f4612d90718` |
| `opfit-281-class-a-premerge-pipeline` | A — operational fit / pipeline | #281 | #288 | `e8f5f96c44568a32e40ce1995b9ffb80c0009d28` |
| `opfit-326-class-b-premerge-pipeline` | B — reasoning / code / pipeline | #326 | #358 | `f3145229b2ad8044519ed1c1f88b5f4612d90718` |

The runner refuses to run when `TASK=<id>` does not resolve to a task file, when the task file lacks `task_class`, or when the rendered prompt still contains benchmark placeholder text such as `INJECTED PER ROUND`.

## Execution reality

The local `scripts/benchmark/` runner is the execution base for monolithic,
context-injected, pipeline, and duo benchmark runs. The historical results now
cover the paid Stage 1 screen and follow-on experiments; use
[`benchmark-runbook.md`](./benchmark-runbook.md) when repeating or extending the
benchmark.

| Protocol requirement | Prototype status in this worktree | Notes |
|---|---|---|
| Canonical candidate prompt at `.github/prompts/model-roi-benchmark-candidate.md` | Present | `scripts/benchmark/lib.sh` points at this path. |
| Concrete task injection files for Class A and Class B | Present | `scripts/benchmark/lib.sh` renders `.context/benchmarks/model-roi/tasks/<TASK>.md` into each run. |
| Core Stage 1 operator flow (`base`, `run`, `suite`, `worktree`, `record`, `collect`, `unseal`) | Present | Driven by `scripts/benchmark/Makefile` and companion scripts. |
| Real pre-spend `doctor` gate | Present | `make doctor` checks prompt/manifest/base, per-harness binaries, auth heuristics, writable dirs, and remote readiness before spend. |
| Hard refusal to widen Phase A when `STAGE=1` is omitted | Present | `make suite` / `run-suite.sh` fail fast unless Stage 1 is selected explicitly. |
| Completeness enforcement for every Core Stage 1 alias terminal state | Present | `run-suite.sh` records the executed alias set and a sealed manifest snapshot; `collect` / `unseal` require exactly one terminal result per recorded alias. |
| Blind vs. sealed artifact split | Present | Model identity and detailed effort metadata stay sealed; blind surfaces expose only alias-safe operational facts. |
| Documented manual fallback after automated runtime failure | Present | Automated candidate failures keep the worktree and may be finished via `make record`; never count this as silent automated success. |

## Current Operator Flow

The commands below reflect the current monolithic Stage 1 operator flow. For a
full reproduction guide, including context injection, pipeline, duo, telemetry,
and known issues, use [`benchmark-runbook.md`](./benchmark-runbook.md).

1. Choose one committed task id, for example `opfit-281-class-a` or `opfit-326-class-b`.
2. Create the sealed manifest by copying `scripts/benchmark/candidates.tsv.example` to `scripts/benchmark/candidates.tsv`, then edit only the sealed mapping.
3. Freeze the benchmark base:

   ```bash
   make -C scripts/benchmark base TASK=<task-id>
   ```

4. Run the Core Stage 1 suite:

   ```bash
   make -C scripts/benchmark suite TASK=<task-id> BASE=<base-sha> STAGE=1
   ```

5. Run one alias in isolation when needed:

   ```bash
   make -C scripts/benchmark run TASK=<task-id> BASE=<base-sha> ALIAS=<cand-NN>
   ```

6. If a bundled adapter fails during the automated run and the benchmark owner approves manual capture, keep the aliased worktree and record the run explicitly:

   ```bash
   make -C scripts/benchmark worktree TASK=<task-id> BASE=<base-sha> ALIAS=<cand-NN>
   make -C scripts/benchmark record TASK=<task-id> BASE=<base-sha> ALIAS=<cand-NN> RC=<rc>
   ```

7. Build the blind grading sheet only after every Core Stage 1 alias reaches a terminal state:

   ```bash
   make -C scripts/benchmark collect TASK=<task-id>
   ```

8. Reveal alias identity only after grading is locked:

   ```bash
   make -C scripts/benchmark unseal TASK=<task-id>
   ```

## Issue #376 pipeline flow

Issue #376 reuses the same frozen-base and blind-artifact apparatus, but uses a
pipeline-specific prompt and candidate manifest:

```bash
cp scripts/benchmark/orchestration-candidates.tsv.example scripts/benchmark/orchestration-candidates.tsv
make -C scripts/benchmark run \
  TASK=opfit-281-class-a-premerge-pipeline \
  BASE=<base-sha> \
  ALIAS=cand-12-pipe \
  MANIFEST=orchestration-candidates.tsv \
  PROMPT_FILE=../../.github/prompts/model-roi-orchestration-pipeline-candidate.md \
  BENCHMARK_SUBISSUE=#376 \
  ORCHESTRATION_VARIANT=pipeline-same-model
```

Use `ORCHESTRATION_VARIANT=pipeline-existing-overlays` for `cand-03-pipe` to
measure the committed Copilot tiered-overlay baseline. Use
`ORCHESTRATION_VARIANT=pipeline-same-model` for same-model and auto-router
pipeline candidates.

## Stage 1D duo workflow

Stage 1D reuses the same Class A/Class B frozen bases, but runs a planner model
first and an implementer model second. The planner worktree is separate and
plan-only; the implementer worktree starts clean from the frozen base and
receives the planner artifact in its prompt.

```bash
cp scripts/benchmark/duo-candidates.tsv.example scripts/benchmark/duo-candidates.tsv

make -C scripts/benchmark duo-suite \
  TASK=opfit-281-class-a-premerge \
  BASE=6946d04b3fd17014e32d9da5ea947acf6df14360 \
  STAGE=1d

make -C scripts/benchmark duo-suite \
  TASK=opfit-326-class-b-premerge \
  BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6 \
  STAGE=1d
```

Single-candidate runs use `duo-run`:

```bash
make -C scripts/benchmark duo-run \
  TASK=opfit-281-class-a-premerge \
  BASE=6946d04b3fd17014e32d9da5ea947acf6df14360 \
  ALIAS=cand-12-duo
```

Total Stage 1D ROI must include planner cost plus implementer cost. Do not
compare an implementer-only cost against monolithic candidates.

## Targeted Context-Pack Stage (1E)

Stage 1E tests **named small context packs** as a middle path between baseline
lazy loading and full `.context/rules/*.md` injection. Issue #374/#376 showed
full-rule injection can help weaker runs but often hurts ROI for the best
candidates; Stage 1E measures the sweet spot.

Supported `CONTEXT_VARIANT` values:

```text
baseline
agents-import-only
full-rules-injected
pack:<pack-id>    # e.g. pack:core-min, pack:class-a-process
```

Use `RUN_GROUP=<id>` when running multiple variants against the same task so
artifacts land under `scripts/benchmark/runs/<task>/groups/<run-group>/` and do
not overwrite each other.

### Pack list

| Pack ID | Use |
|---|---|
| `core-min` | Index, ownership map, latest session summary |
| `class-a-process` | Class A process/doc/PR completion rules |
| `class-b-implementation` | Class B code quality + doc-sync rules |
| `workflow-risk` | ADR-016 + sandbox verification for risky workflow edits |
| `adr-docs` | ADR index/template + model tier + orchestration patterns |

### CP-1 pack screen commands

```bash
CLASS_A_BASE=6946d04b3fd17014e32d9da5ea947acf6df14360
CLASS_B_BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6
PACK_SCREEN_MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example"

RUN_GROUP=ctx-a-core-min \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE="$CLASS_A_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:core-min
```

Repeat with `RUN_GROUP` and `CONTEXT_VARIANT` for the Class A matrix
(`baseline`, `pack:core-min`, `pack:class-a-process`, `full-rules-injected`)
and Class B matrix (`baseline`, `pack:core-min`, `pack:class-b-implementation`,
`full-rules-injected`). See [`benchmark-runbook.md`](./benchmark-runbook.md).

Collect per group (do **not** unseal before blind scores are locked):

```bash
RUN_GROUP=ctx-a-core-min \
make -C scripts/benchmark collect \
  TASK=opfit-281-class-a-premerge \
  STAGE=1
```

### Sweet-spot decision rule

```text
sweet_spot_pack =
  highest marginal ROI pack
  with score >= best_score_for_task_class - 2
  and no model-specific degradation > 3 points
  and lower injected bytes/tokens than full-rules injection
```

If no pack meets this threshold, recommend baseline lazy loading plus targeted
manual reads — not automatic full-rule injection.

**Caveat:** Stage 1E is benchmark evidence only. It does not change production
model routing or default context loading without a separate ADR/policy PR.

## Artifact model

The benchmark keeps **grader-facing** and **sealed** artifacts separate.

### Sealed inputs

- `scripts/benchmark/candidates.tsv` — alias→platform/model/agent manifest
- `scripts/benchmark/runs/<task-id>/stage-<stage>-manifest.tsv` — frozen sealed manifest snapshot captured by `run-suite.sh`

### Per-run artifacts

Each run writes under:

```text
scripts/benchmark/runs/<task-id>/<alias>/r<run-index>/
```

Expected artifacts:

- `diff.patch` — candidate diff against the frozen base
- `meta-blind.json` — alias, timing, git facts, and other grader-safe metadata
- `meta-sealed.json` — platform/model/agent identity and sealed metadata
- `agent-output.jsonl` — raw machine-readable agent output
- `logs/` — adapter stderr and runtime logs

Stage 1D duo runs additionally write:

- `planner/agent-output.jsonl` — planner raw output
- `planner/plan.md` — extracted planner artifact passed to the implementer
- `implementer/agent-output.jsonl` — implementer raw output
- `implementer/logs/` — implementer stderr/runtime logs

### Task-level artifacts

- `scripts/benchmark/runs/<task-id>/stage-<stage>-aliases.txt` — recorded alias set for the executed suite
- `scripts/benchmark/runs/<task-id>/grading-sheet-blind.tsv` — blind grading sheet
- `scripts/benchmark/runs/<task-id>/unsealed-map.tsv` — post-lock alias reveal

Detailed effort controls belong in sealed records only. Blind artifacts should not expose model identity or detailed effort metadata.

## Core Stage 1 terminal states

Every Core Stage 1 alias in the recorded suite alias set must end in **exactly one** audited terminal state before blind collection or unseal:

- `graded`
- `blocked`
- `manual-capture-approved`

The runner now enforces this automatically at collect/unseal time; the templates remain the human-readable audit surface.

## Templates

- Use [`result-template.md`](./result-template.md) once per alias/run.
- Use [`summary-template.md`](./summary-template.md) once per task after every Core Stage 1 alias reaches a terminal state.
- If the docs and the runner ever disagree, follow the higher-priority source for the current task and note the mismatch in the summary instead of guessing.
