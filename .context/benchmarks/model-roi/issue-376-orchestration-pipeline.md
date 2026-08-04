# Issue 376 Orchestration Pipeline Benchmark

> Sub-issue: #376
> Parent strategy issue: #220
> Reuses apparatus from issue #374: frozen base, aliased branches, sealed
> manifest, blind grading, result artifacts, marginal ROI, and no candidate PRs
> merged into `main`.

## Experiment Question

Does an agent pipeline with repo-native role dispatch produce better
quality-per-dollar than the strongest monolithic Stage 1 candidates on the same
Class A and Class B tasks?

This run intentionally does **not** rerun the monolithic baselines. The baseline
evidence is the completed Stage 1 / Stage 1C result set in
`docs/benchmarks/agent-roi-benchmark-results.md`.

## Scope

- Run the same Class A and Class B benchmark tasks used for Stage 1.
- Enable subagents and handoff behavior; orchestration is the unit under test.
- Record end-to-end cost, wall time, role dispatch behavior, and final diff
  quality.
- Compare against the existing monolithic baselines, not against a new Stage 2
  effort sweep.

Out of scope:

- Changing ADR-019 role tier policy.
- Merging candidate branches.
- Using an LLM as the deterministic benchmark dispatcher.
- Rerunning monolithic baselines unless a harness bug invalidates a specific
  baseline cell.

## Candidates

| Alias | Platform / model | Overlay policy | Purpose |
|---|---|---|---|
| `cand-03-pipe` | Copilot / Opus 4.8 | Existing `.github/agents/*.agent.md` model pins | Orchestration baseline using the repo's current tiered Copilot overlays. |
| `cand-12-pipe` | Claude Code / Opus 4.8 | Patch `.claude/agents/*.md` in the candidate worktree so every role uses Opus | Strong same-model pipeline. |
| `cand-05-pipe` | Claude Code / Haiku | Patch `.claude/agents/*.md` in the candidate worktree so every role uses Haiku | Cheap same-model pipeline. |
| `cand-20-pipe` | Cursor / Auto | Patch `.cursor/agents/*.md` to `model: inherit` so parent Auto routing governs role dispatch | Auto-router pipeline. |
| `cand-21-pipe` | Gemini/agy / Auto | Generate `.gemini/agents/*.md` from `.agents/*.md` and omit per-role model pins | Auto-router pipeline with generated Gemini overlays. |

## Harness Invocation

Create a dedicated manifest from:

```bash
cp scripts/benchmark/orchestration-candidates.tsv.example scripts/benchmark/orchestration-candidates.tsv
```

Run the Copilot tiered-overlay baseline separately from the same-model overlay
batch so the overlay policy is explicit:

```bash
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge-pipeline \
  BASE=<class-a-base-sha> \
  STAGE=1 \
  MANIFEST=orchestration-candidates.tsv \
  PROMPT_FILE=../../.github/prompts/model-roi-orchestration-pipeline-candidate.md \
  BENCHMARK_SUBISSUE=#376 \
  ORCHESTRATION_VARIANT=pipeline-existing-overlays
```

For same-model candidates, run one alias at a time so the overlay policy matches
the candidate:

```bash
make -C scripts/benchmark run \
  TASK=opfit-281-class-a-premerge-pipeline \
  BASE=<class-a-base-sha> \
  ALIAS=cand-12-pipe \
  MANIFEST=orchestration-candidates.tsv \
  PROMPT_FILE=../../.github/prompts/model-roi-orchestration-pipeline-candidate.md \
  BENCHMARK_SUBISSUE=#376 \
  ORCHESTRATION_VARIANT=pipeline-same-model
```

Repeat for:

- `opfit-281-class-a-premerge-pipeline`
- `opfit-326-class-b-premerge-pipeline`

## Overlay Handling

The benchmark runner patches or generates role overlays only inside the
candidate worktree. It captures `orchestration-overlay.json`, marks patched
tracked overlays `skip-worktree`, runs the candidate, then restores/removes the
overlay files before diff capture.

This keeps the candidate deliverable diff focused on the assigned task while
still making the role routing policy auditable.

## Grading

Use the issue #376 rubric:

| Category | Weight |
|---|---:|
| Correctness / acceptance | 30 |
| Code and doc quality | 20 |
| Repo-process adherence | 15 |
| End-to-end reliability | 15 |
| Coordination efficiency | 10 |
| Latency | 10 |
| Total | 100 |

Grade blind against the same reference PRs used in Stage 1. A candidate may
beat the reference if it satisfies acceptance criteria with a smaller, cleaner,
or more robust solution.

## Comparison Output

Add the final results to `docs/benchmarks/agent-roi-benchmark-results.md` in a new
issue 376 pipeline section. Report:

- Alias
- Task class
- Weighted score
- Wall seconds
- Marginal cost USD where telemetry supports it
- Marginal ROI
- Overlay policy
- Role dispatch evidence observed in `agent-output.jsonl`
- Deviations, including missing token telemetry or failed subagent handoffs

Then address:

- H1: Does a tiered pipeline beat strong monolithic candidates on complex tasks?
- H2: Does orchestration hurt ROI on simple tasks?
- H3: Does cheap-model orchestration alone carry quality?
- H4: Is there a crossover point between Class A and Class B?
