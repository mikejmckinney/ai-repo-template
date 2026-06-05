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
[`results/agent-roi-benchmark-results.md`](./results/agent-roi-benchmark-results.md).

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
