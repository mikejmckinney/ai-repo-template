# Agent ROI Benchmark Runbook

This runbook describes how to reproduce the agent/model ROI benchmark used for
issues #374 and #376, and how to extend it when new models are released.

Use it with:

- Protocol and artifact contract: [`README.md`](./README.md)
- Current results and ROI analysis: [`results/agent-roi-benchmark-results.md`](./results/agent-roi-benchmark-results.md)
- Candidate prompt: [`.github/prompts/model-roi-benchmark-candidate.md`](../../../.github/prompts/model-roi-benchmark-candidate.md)
- Runner entrypoint: [`scripts/benchmark/Makefile`](../../../scripts/benchmark/Makefile)

Benchmark prompts and task files are separate by design:

- `.github/prompts/` stores reusable execution wrappers, such as monolithic
  candidate, duo planner, duo implementer, and orchestration-pipeline prompts.
- `.context/benchmarks/model-roi/tasks/` stores benchmark payloads: the task
  body injected into a run, acceptance criteria, verification expectations, and
  sealed reference metadata.

## Benchmark Intent

The benchmark is repo-local. It does not rank models universally. It measures
how well each agent/harness/model combination performs on this repository's
workflow, context pack, task style, verification expectations, and billing
shape.

The primary decision metric is:

```text
marginal ROI = score / marginal cost USD
```

Interpret ROI alongside correctness, process compliance, wall-clock time,
telemetry quality, and harness-specific billing behavior.

## Standard Task Set

Use the same Class A and Class B tasks for comparable future screens unless the
benchmark plan explicitly changes the task set.

| Class | Task id | Purpose | Frozen base SHA used in the completed run |
|---|---|---|---|
| A | `opfit-281-class-a-premerge` | Small operational-fit shell-check change | `6946d04b3fd17014e32d9da5ea947acf6df14360` |
| B | `opfit-326-class-b-premerge` | Larger reasoning/code helper with docs and tests | `cff89bffe7e15e155bd740b6c7a0f158a6f2bad6` |

For a new benchmark session, either reuse the frozen base SHAs to compare
against the historical record, or deliberately freeze new bases and record the
new base SHA in the results doc. Do not mix old and new bases without calling
out the comparability caveat.

## One-Time Setup

Run from the repository root.

```bash
cp scripts/benchmark/candidates.tsv.example scripts/benchmark/candidates.tsv
cp scripts/benchmark/duo-candidates.tsv.example scripts/benchmark/duo-candidates.tsv
cp scripts/benchmark/orchestration-candidates.tsv.example scripts/benchmark/orchestration-candidates.tsv
```

Edit the local manifest files to match the exact picker names exposed by the
installed CLIs. The real manifest files are gitignored because they unseal
alias-to-model identity.

Authenticate the CLIs you plan to use:

```bash
# Examples only; use the auth path required by your account.
export COPILOT_GITHUB_TOKEN=...
codex login
claude login
cursor-agent login
gemini auth login
```

Before spending on a large run, use the doctor gate for Stage 1:

```bash
make -C scripts/benchmark doctor STAGE=1 BASE=<base-sha>
```

## Freeze Or Reuse Bases

To freeze a new base from `origin/main`:

```bash
make -C scripts/benchmark base TASK=opfit-281-class-a-premerge
make -C scripts/benchmark base TASK=opfit-326-class-b-premerge
```

For historical comparability, reuse the completed-run bases:

```bash
CLASS_A_BASE=6946d04b3fd17014e32d9da5ea947acf6df14360
CLASS_B_BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6
```

## Monolithic Stage 1 Runs

Run the standard aliased candidate suite sequentially:

```bash
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE=$CLASS_A_BASE \
  STAGE=1

make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE=$CLASS_B_BASE \
  STAGE=1
```

Run a single candidate when debugging:

```bash
make -C scripts/benchmark run \
  TASK=opfit-281-class-a-premerge \
  BASE=$CLASS_A_BASE \
  ALIAS=cand-21
```

Prefer sequential runs when comparing `wall_s`. Parallel runs can reduce total
operator time, but they introduce host-load and provider-rate-limit noise that
makes wall-clock comparisons less clean.

## Context-Injection Stage 1C Runs

Stage 1C tests whether injecting `.context/rules/*.md` into the agent context
improves performance or ROI.

```bash
MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1c-candidates.tsv" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE=$CLASS_A_BASE \
  STAGE=1 \
  CONTEXT_VARIANT=full-rules-injected

MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1c-candidates.tsv" \
make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE=$CLASS_B_BASE \
  STAGE=1 \
  CONTEXT_VARIANT=full-rules-injected
```

Claude Code requires `@AGENTS.md` in `CLAUDE.md` to guarantee the injected
context is visible. The completed benchmark suggests this can matter for Haiku
and Sonnet.

## Targeted Context-Pack Stage 1E Runs

Stage 1E (issue #378) compares baseline lazy loading, named context packs, and
full-rule injection on the historical Class A/Class B premerge bases. Use
`RUN_GROUP` for every variant so runs do not collide.

```bash
CLASS_A_BASE=6946d04b3fd17014e32d9da5ea947acf6df14360
CLASS_B_BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6
PACK_SCREEN_MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example"
```

Class A matrix (one command per variant):

```bash
RUN_GROUP=ctx-a-baseline MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-281-class-a-premerge BASE="$CLASS_A_BASE" STAGE=1 CONTEXT_VARIANT=baseline

RUN_GROUP=ctx-a-core-min MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-281-class-a-premerge BASE="$CLASS_A_BASE" STAGE=1 CONTEXT_VARIANT=pack:core-min

RUN_GROUP=ctx-a-class-a-process MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-281-class-a-premerge BASE="$CLASS_A_BASE" STAGE=1 CONTEXT_VARIANT=pack:class-a-process

RUN_GROUP=ctx-a-full-rules MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-281-class-a-premerge BASE="$CLASS_A_BASE" STAGE=1 CONTEXT_VARIANT=full-rules-injected
```

Class B matrix:

```bash
RUN_GROUP=ctx-b-baseline MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-326-class-b-premerge BASE="$CLASS_B_BASE" STAGE=1 CONTEXT_VARIANT=baseline

RUN_GROUP=ctx-b-core-min MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-326-class-b-premerge BASE="$CLASS_B_BASE" STAGE=1 CONTEXT_VARIANT=pack:core-min

RUN_GROUP=ctx-b-class-b-implementation MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-326-class-b-premerge BASE="$CLASS_B_BASE" STAGE=1 CONTEXT_VARIANT=pack:class-b-implementation

RUN_GROUP=ctx-b-full-rules MANIFEST="$PACK_SCREEN_MANIFEST" \
  make -C scripts/benchmark suite TASK=opfit-326-class-b-premerge BASE="$CLASS_B_BASE" STAGE=1 CONTEXT_VARIANT=full-rules-injected
```

Collect each group after all aliases reach a terminal state:

```bash
RUN_GROUP=ctx-a-core-min make -C scripts/benchmark collect \
  TASK=opfit-281-class-a-premerge STAGE=1
```

Unseal only after blind scores are locked:

```bash
RUN_GROUP=ctx-a-core-min make -C scripts/benchmark unseal \
  TASK=opfit-281-class-a-premerge STAGE=1
```

Pack manifests live in `.context/benchmarks/model-roi/context-packs/`. Unknown
pack ids and unsafe manifest paths fail before spend.

### Regrade Stage 1E (CP-1) under a canonical score set

Stage 1E exploratory scores (e.g. `stage-1e-blind-scores-locked.tsv`) are **not**
canonical until regraded with the standardized pipeline. Use the operator script:

```bash
# From repo root — default score-set prefix: stage-1e-canonical-v1
./scripts/benchmark/regrade-stage-1e.sh prepare

# Or via Makefile:
make -C scripts/benchmark regrade-stage-1e ARGS="prepare"
```

This runs **all eight** `RUN_GROUP`s through:

1. `grade-bundles` — blind `eval-###` bundles + sealed map (no pack/model leakage)
2. `grade-objective` — deterministic objective points
3. `grade-subjective-prompts` — one `subjective-prompt.md` per eval

It writes a manifest listing every subjective prompt:

```text
scripts/benchmark/grade-bundles/stage-1e-regrade-manifest.txt
```

Per-group score set ids: `<prefix>-<run_group>` (e.g.
`stage-1e-canonical-v1-ctx-b-core-min`). Override prefix:

```bash
SCORE_SET_PREFIX=stage-1e-canonical-v2 ./scripts/benchmark/regrade-stage-1e.sh prepare
```

**Subjective step (manual or locked LLM):** grade each `subjective-prompt.md` with
[`.github/prompts/model-roi-grader-v1.md`](../../../.github/prompts/model-roi-grader-v1.md).
Output must be JSON matching `subjective-grade.schema.json`. Save files as:

```text
stage-1e-responses/
  ctx-a-baseline/eval-001.json
  ctx-a-baseline/eval-002.json
  ctx-b-core-min/eval-001.json
  ...
```

**Record + compile:**

```bash
./scripts/benchmark/regrade-stage-1e.sh record codex-fixed ./stage-1e-responses
./scripts/benchmark/regrade-stage-1e.sh compile codex-fixed

# Or one shot (if responses already exist):
./scripts/benchmark/regrade-stage-1e.sh all codex-fixed ./stage-1e-responses
```

**Status check:**

```bash
./scripts/benchmark/regrade-stage-1e.sh status
```

Final scores per group:

```text
scripts/benchmark/grade-bundles/<task>/<score-set-id>/final-grades.tsv
```

Unseal alias → model only **after** scores are locked, using each group's
`sealed-eval-map.tsv` (not the blind bundles).

See also [`.context/benchmarks/model-roi/grading/README.md`](./grading/README.md).

## Duo Planner/Implementer Stage 1D Runs

Stage 1D tests a planning model followed by a cheaper implementer. ROI must use
planner cost plus implementer cost.

```bash
make -C scripts/benchmark duo-suite \
  TASK=opfit-281-class-a-premerge \
  BASE=$CLASS_A_BASE \
  STAGE=1d

make -C scripts/benchmark duo-suite \
  TASK=opfit-326-class-b-premerge \
  BASE=$CLASS_B_BASE \
  STAGE=1d
```

Single-candidate run:

```bash
make -C scripts/benchmark duo-run \
  TASK=opfit-326-class-b-premerge \
  BASE=$CLASS_B_BASE \
  ALIAS=cand-20-duo
```

## Orchestration Pipeline Runs

Issue #376 measures multi-role orchestration against the monolithic baselines.

```bash
make -C scripts/benchmark run \
  TASK=opfit-281-class-a-premerge-pipeline \
  BASE=$CLASS_A_BASE \
  ALIAS=cand-20-pipe \
  MANIFEST=orchestration-candidates.tsv \
  PROMPT_FILE=../../.github/prompts/model-roi-orchestration-pipeline-candidate.md \
  BENCHMARK_SUBISSUE=#376 \
  ORCHESTRATION_VARIANT=pipeline-same-model
```

Use `ORCHESTRATION_VARIANT=pipeline-existing-overlays` for the committed
Copilot tiered-overlay baseline. Use `pipeline-same-model` for same-model and
auto-router pipeline candidates.

## Manual Antigravity Runs

Antigravity is not a normal headless CLI in this harness. To test it directly,
create an isolated worktree, run Antigravity inside that worktree, then capture
the diff and telemetry.

```bash
make -C scripts/benchmark worktree \
  TASK=opfit-281-class-a-premerge \
  BASE=$CLASS_A_BASE \
  ALIAS=<manual-alias>
```

Open the printed worktree in Antigravity, select the target model, and run the
candidate prompt plus the task body. Do not push or open a PR from the agent.

Capture:

- model actually used
- input, cached, output, and reasoning/thinking tokens when exposed
- wall-clock start and end
- cost or billing export source
- final diff against the frozen base

The current `make record` path is intentionally conservative and expects a
prior blocked automated run. If direct Antigravity testing becomes routine, add
an explicit `--allow-new-manual` capture mode rather than weakening the default
guard.

## Collect, Grade, And Unseal

After every alias reaches a terminal state:

```bash
make -C scripts/benchmark collect TASK=<task-id>
```

### Standardized grading (canonical score sets)

Use the script-first grading pipeline under
[`.context/benchmarks/model-roi/grading/README.md`](./grading/README.md).
Scores are comparable **only within the same `score_set_id`**.

**Results column layout** (in [`results/agent-roi-benchmark-results.md`](./results/agent-roi-benchmark-results.md)):

| Column | Max | Meaning |
|---|---:|---|
| Legacy /100 | 100 | Pre-pipeline holistic blind grade (category columns sum to this) |
| Canonical /100 | 100 | `rubric.v1` final total (objective + subjective) |
| Objective /65 | 65 | Automated checks (syntax, paths, scope, latency bands, …) |
| Subjective /35 | 35 | Locked grader JSON (`model-roi-grader-v1`) |
| score_set_id | — | Cohort id; required for comparable conclusions |

Regrade operator scripts (from repo root):

```bash
GRADER=cursor-llm-blind-v1

# Unified driver (stages: 1 | 1c | 1d | pipeline | 1e)
# Actions: prepare | grade | record | compile | status | all

# Stage 1 monolithic (46 bundles; responses in stage-1-llm-responses-v1/)
./scripts/benchmark/regrade-stage.sh 1 prepare
./scripts/benchmark/regrade-stage.sh 1 grade "${GRADER}"
./scripts/benchmark/regrade-stage.sh 1 record "${GRADER}" scripts/benchmark/stage-1-llm-responses-v1
./scripts/benchmark/regrade-stage.sh 1 compile "${GRADER}"

# Stage 1C / 1D / pipeline (responses in stage-llm-responses-v1/)
RESP=scripts/benchmark/stage-llm-responses-v1
./scripts/benchmark/regrade-stage.sh 1c prepare
SKIP_LEGACY_RESPONSES=1 ./scripts/benchmark/regrade-stage.sh 1c prepare   # skip legacy bootstrap

# True LLM blind grade (Cursor agent + model-roi-grader-v1 on each subjective-prompt.md)
./scripts/benchmark/regrade-stage.sh 1c grade "${GRADER}"
# or: python3 scripts/benchmark/blind_grade_stage.py --stage 1c --grader-id "${GRADER}" --skip-existing

./scripts/benchmark/regrade-stage.sh 1c record "${GRADER}" "${RESP}"
bash ./scripts/benchmark/regrade-stage.sh 1c compile "${GRADER}"

# Repeat for 1d and pipeline; thin wrappers (regrade-stage-1c.sh, …) exec regrade-stage.sh

# Offline heuristic only (fixtures / CI): blind_grade_bundle.py --heuristic

# Stage 1E CP-1 (eight RUN_GROUP score sets)
./scripts/benchmark/regrade-stage-1e.sh prepare
# … grade each subjective-prompt.md → stage-1e-responses-v2/<run_group>/eval-NNN.json
./scripts/benchmark/regrade-stage-1e.sh grade cursor-llm-blind-v1
./scripts/benchmark/regrade-stage-1e.sh record cursor-llm-blind-v1 scripts/benchmark/stage-1e-llm-responses-v1
./scripts/benchmark/regrade-stage-1e.sh compile cursor-llm-blind-v1

# Refresh results.md: canonical columns, ROI numerators, per-table sort notes
python3 scripts/benchmark/update-benchmark-results.py all   # scores | roi | sort | all
```

**Canonical grader (all stages, 2026-06):** `cursor-llm-blind-v1` via
`llm_grade_subjective.py` (not the superseded heuristic `blind_grade_heuristic.py`).

**Response directories** (local audit trail; not on `main` after Phase A merge):

| Stage | Directory |
|---|---|
| 1 monolithic | `scripts/benchmark/stage-1-llm-responses-v1/` |
| 1C / 1D / pipeline | `scripts/benchmark/stage-llm-responses-v1/` |
| 1E CP-1 | `scripts/benchmark/stage-1e-llm-responses-v1/` (`<run_group>/eval-NNN.json`) |

Stage 1 and 1D share task ids (`opfit-281-class-a-premerge`, …) — keep separate response
dirs so eval ids do not collide. Restore these dirs from git tag
`benchmark/phase-a-artifacts-20260608` or branch `benchmark/roi` before running
`record` / `compile` to reproduce canonical numbers.

### Branch and fixture retention (Phase A → `main`)

Phase A merges **harness, rubrics, runbook, and published `results.md`** to `main`.
Large subjective JSON fixtures and legacy bootstrap dirs stay off `main`:

| Surface | What merges to `main` | What stays on `benchmark/roi` / tag |
|---|---|---|
| `main` | Scripts, rubrics, tasks, runbook, `agent-roi-benchmark-results.md` | — |
| Tag `benchmark/phase-a-artifacts-20260608` | — | Full pre-cleanup branch tip (all `stage-*-llm-responses-v1/`, legacy `stage-*-responses/`) |
| Branch `benchmark/roi` (post-merge) | Harness updates merged from `main` | Fixture trees + ongoing benchmark runs |

Post-merge maintainer steps (**completed 2026-06-08**):

1. ~~Push tag `benchmark/phase-a-artifacts-20260608` to `origin`.~~ Done.
2. ~~Merge Phase A PR #379 to `main` (`eb8fff6`).~~ Done.
3. ~~Create `benchmark/roi` from tag `benchmark/phase-a-artifacts-20260608`.~~ Done.
4. ~~Merge `main` into `benchmark/roi` and re-commit `stage-*-llm-responses-v1/` fixtures~~ (fast-forward dropped tracked fixtures; restored from tag on `benchmark/roi`).
5. **Next:** run `06-implement-class-c-framework-benchmark.md` on `benchmark/roi` when Class C evidence is prioritized.

Deferred harness items from PR #379 bot triage: [FOLLOW_UPS.md](./FOLLOW_UPS.md).

**Class A vs Class B row scoping:** Monolithic, 1C, 1D, and pipeline tables can share the
same alias string across task classes (e.g. `cand-06`, `cand-05-pipe` at `r2`). Results sync
uses `lookup_stage_score()` / `lookup_pipeline_score()` scoped by task class — never merge
Class A and Class B `final-grades.json` rows into one `(alias, run)` map.

**Orphan `agent` processes:** `llm_grade_subjective.py` starts each grade in a new session
and `SIGKILL`s the process group on timeout. Before long batches, check
`pgrep -af '/home/codespace/.local/bin/agent'` and kill stale PIDs not owned by the IDE
(compare `ps -o pid,tty,etime,cmd -p <pid>`). Do not kill the interactive IDE agent on `pts/0`.

**Results table conventions** (see `results/agent-roi-benchmark-results.md`):

- Marginal ROI tables include **Objective | Subjective** and resolve extended-stage
  aliases (`-pipe`, `-injected`, `-duo`) within each task class (Class A vs B).
- Stage 1C tables include **ROI delta** = injected ROI − baseline ROI (same alias).
- Issue #376 pipeline tables use separate **Cost USD** and **ROI** columns for sort.

### Reproducing canonical scores (what to commit vs regenerate)

| Artifact | On `main`? | Role |
|---|---|---|
| `results/agent-roi-benchmark-results.md` | **Yes** | Published tables + ROI (canonical columns already compiled in) |
| Rubrics, task specs, scripts | **Yes** | Tooling |
| `stage-*-llm-responses-v1/` JSON | **No** (tag / `benchmark/roi`) | Locked subjective grader output (`cursor-llm-blind-v1`) |
| `grade-bundles/`, `runs/`, `worktrees/` | **No** (gitignored) | Regenerate via `prepare` + sealed manifests from `results.md` |
| `stage-*-responses/` legacy bootstrap dirs | **No** | Superseded by `stage-*-llm-responses-v1/`; optional local audit only |
| Spot-check JSON (`stage-1-cand06-*`, `stage-1-ctx-cur-*`) | **No** | Ad-hoc experiments; not part of canonical score sets |
| `stage-1e-responses-v2/` | **No** | Prior `cursor-session-stage-1e-v2` session; superseded by `stage-1e-llm-responses-v1/` |
| `*.bak-*` editor backups | **No** | Never commit |

To reproduce canonical numbers from scratch: check out tag `benchmark/phase-a-artifacts-20260608`
(or `benchmark/roi`) for response JSON → `record` → `compile` →
`update-benchmark-results.py all` (requires local `grade-bundles/` from `prepare`).
On `main` alone, trust the published canonical columns in `results.md` unless you
restore fixtures from the tag.

### Why Class A canonical scores look lower than Class B

The same `rubric.v1` (100 points) applies to both tasks, but **task grading specs**
(`grading/tasks/opfit-281-*.json` vs `opfit-326-*.json`) set different objective
checklists. In bundle-only regrades, that creates different **objective ceilings**:

| Factor | Class A (`opfit-281`) | Class B (`opfit-326`) |
|---|---|---|
| Required deliverable paths | 1 file (`055-script-syntax.sh`) | 4 paths + 2 doc companions |
| Correctness objective (typical) | ~4 / 20 | ~18 / 20 |
| `full_test_sh` in bundle grading | disabled | disabled |
| Mean canonical total (Stage 1 LLM) | ~63 | ~78 |
| Mean subjective total | ~26 | ~28 |

Class A candidates often score well on **subjective** quality (~26–28/35) but cannot
earn much **objective correctness** without running acceptance commands against a live
worktree. Class B multi-file deliverables automatically pass more path/doc checks, so
objective totals are higher even when the underlying task is harder.

**Do not rank Class A vs Class B by raw canonical /100** — use marginal ROI within each
task class. Legacy /100 columns used holistic blind grades and are closer to cross-class
comparison (with caveats).

Manual per-task example:

```bash
SCORE_SET=stage-1-canonical-v1

make -C scripts/benchmark grade-bundles \
  TASK=opfit-326-class-b-premerge STAGE=1 SCORE_SET="${SCORE_SET}" \
  MANIFEST=scripts/benchmark/grade-bundles/stage-1-canonical-v1-manifests/opfit-326-class-b-premerge-manifest.tsv

make -C scripts/benchmark grade-objective \
  TASK=opfit-326-class-b-premerge SCORE_SET="${SCORE_SET}"

make -C scripts/benchmark grade-subjective-prompts \
  TASK=opfit-326-class-b-premerge SCORE_SET="${SCORE_SET}"

# After a locked grader returns JSON matching subjective-grade.schema.json:
make -C scripts/benchmark grade-subjective-record \
  TASK=opfit-326-class-b-premerge SCORE_SET="${SCORE_SET}" \
  EVAL_ID=eval-001 GRADER_ID=<stable-id> RESPONSE=/path/to/response.json

make -C scripts/benchmark grade-compile \
  TASK=opfit-326-class-b-premerge SCORE_SET="${SCORE_SET}" GRADER_ID=<stable-id>
```

Each stage has a dedicated regrade wrapper and `score_set_id`:

| Stage | Script | Default score set | Canonical grader (extended stages) |
|---|---|---|---|
| 1 monolithic | `regrade-stage.sh 1` | `stage-1-canonical-v1` | `cursor-llm-blind-v1` |
| 1C injection | `regrade-stage.sh 1c` | `stage-1c-canonical-v1` | `cursor-llm-blind-v1` |
| 1D duo | `regrade-stage.sh 1d` | `stage-1d-canonical-v1` | `cursor-llm-blind-v1` |
| #376 pipeline | `regrade-stage.sh pipeline` | `stage-1-pipeline-canonical-v1` | `cursor-llm-blind-v1` (`rubric.pipeline.v1`) |
| 1E CP-1 | `regrade-stage-1e.sh` | `stage-1e-canonical-v1-<run_group>` | `cursor-llm-blind-v1` |

`prepare` bootstraps subjective JSON from legacy category scores via
`regrade-from-results-md.py responses` (residual mapping). For routing decisions,
replace with **fresh blind JSON** from `model-roi-grader-v1.md` and a stable
`grader_id` (`cursor-llm-blind-v1` for all extended stages including 1E).

After `record` + `compile`, refresh published columns with:

```bash
python3 scripts/benchmark/update-benchmark-results.py all
```

`regrade-stage.sh record` and `all` accept an optional trailing `score-set-id`
override (same as `prepare` / `compile`). `make suite-resume` respects `RUN_GROUP`
via `runs_task_base` when skipping aliases that already have terminal results.

Exploratory Cursor/Codex regrades are separate cohorts for inter-rater analysis
only — do not average them into canonical rows.

Grading bundles use neutral `eval-###` IDs and `context_condition` codes
(`cond-001`, …). Real `context_variant` / pack ids live in sealed maps only.

Separate **benchmark execution cost** from **grading LLM cost** in ROI tables when
subjective graders use paid models.

### Legacy manual grading

Grade blind diffs using the documented 100-point rubric:

```text
Correctness / acceptance: 30
Code and doc quality: 25
Repo-process adherence: 20
Reliability / verification: 15
Latency: 10
```

After scores are locked:

```bash
make -C scripts/benchmark unseal TASK=<task-id>
```

Then add the rows to
[`results/agent-roi-benchmark-results.md`](./results/agent-roi-benchmark-results.md),
citing `score_set_id` and grader prompt version for canonical rows.

## Cost And Telemetry Recovery

Keep cost calculations auditable. Preserve both the estimate and the source.

| Platform | Primary telemetry source | Cost note |
|---|---|---|
| Copilot | `/home/codespace/.copilot/session-state/<session-id>/events.jsonl` `session.shutdown.totalNanoAiu` | Convert with `cost_usd = totalNanoAiu / 1e11`; retain `totalPremiumRequests` only as diagnostic metadata. |
| Gemini CLI / agy | JSON output under `stats.models` | Use per-model token buckets. Output cost includes `candidates + thoughts`. Auto may route through Flash Lite plus Flash/Pro backends. |
| Cursor | Adapter-captured `usage.inputTokens`, `usage.cacheReadTokens`, `usage.cacheWriteTokens`, `usage.outputTokens` | Reconcile against Cursor dashboard when possible. Cursor Auto uses Auto pricing, not raw provider pricing. |
| Claude Code | Reported `total_cost_usd` plus prorated Claude Code runtime | Add runtime at the documented runtime rate used in the results register. |
| Codex | JSON usage with input, cached input, output, and reasoning output | Fresh input is total input minus cached input; output includes reasoning output where priced as output. |
| Antigravity | Billing/session UI or exported telemetry | Record manual source and model actually used; do not infer cost from a requested model if the observed backend differs. |

Refresh vendor rates before publishing final conclusions for a new benchmark
session. If a billing export disagrees with the source-register estimate,
preserve the estimate and add a reconciliation note instead of silently
overwriting the historical value.

## Known Issues And Fixes

| Issue | Symptom | Mitigation |
|---|---|---|
| Cursor model suffix parsing | Passing full model strings such as thinking-level suffixes may drop the suffix and route to the base default. | Put the model and thinking directive inline in the prompt and record effort as requested/unverified. |
| Cursor Auto billing | Dashboard may classify Auto differently from provider/API pricing. | Use Cursor Auto rates for `model=auto`; reconcile with dashboard exports when available. |
| Gemini 3.5 picker mismatch | A requested `gemini-3.5-flash` picker can resolve to `gemini-3-flash-preview` in JSON stats. | Compute cost from the observed backend in `stats.models`, and document the requested-vs-observed mismatch. |
| Gemini nested stats | JSON output stores tokens under nested `stats.models`, not shallow usage keys. | Parse `stats.models[*].tokens` and include `thoughts` with output cost. |
| Gemini/agy fallback | `agy` fallback may not emit JSON token stats. | Prefer direct `gemini --output-format json`; use `agy` only when explicitly testing Antigravity behavior and capture manual telemetry. |
| Copilot prompt length | Very long prompts can hit shell argument length limits. | Use prompt attachment/file delivery when prompt length is large. |
| Copilot billing shift | Premium-request counts are no longer reliable cost units. | Use `session.shutdown.totalNanoAiu` and current AI-credit conversion. |
| Claude context visibility | Claude Code may not read all intended context unless `CLAUDE.md` imports `AGENTS.md`. | Keep `@AGENTS.md` in `CLAUDE.md` when measuring context-sensitive runs. |
| Duo cost accounting | Counting only the implementer makes duo workflows look artificially cheap. | Always sum planner and implementer cost. |
| Parallel execution | Parallel batches can distort `wall_s` through local contention and rate limiting. | Run sequentially when wall-clock comparisons matter. |
| Manual capture guard | `make record` requires a documented blocked automated state. | Add a separate explicit manual-only capture path if GUI agents become first-class candidates. |

## Future Candidate Backlog

Consider these in the next benchmark session, subject to CLI availability,
pricing clarity, and telemetry capture:

- DeepSeek V4 Pro
- Mimo v2.5 Pro
- Kimi K2.6
- Grok 4.3

Add each candidate with a sealed alias, verify exact picker strings before the
run, and document whether the harness exposes reasoning-effort controls.
