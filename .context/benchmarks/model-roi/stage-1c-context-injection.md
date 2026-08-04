# Stage 1C Context Injection Benchmark

Issue: #374

## Question

Does injecting the full contents of `.context/rules/*.md` into `AGENTS.md` improve agent performance
or ROI compared with the existing pointer-based `AGENTS.md` startup contract?

## Baseline

Reuse the completed Stage 1 Class A/Class B results as the baseline:

- Class A task: `opfit-281-class-a-premerge`
- Class B task: `opfit-326-class-b-premerge`
- Baseline context style: existing pointer-based `AGENTS.md`
- Baseline results: `docs/benchmarks/agent-roi-benchmark-results.md`

## Injected Variant

Run only the injected condition with the same task content:

- Class A injected task id: `opfit-281-class-a-premerge-context-injected`
- Class B injected task id: `opfit-326-class-b-premerge-context-injected`
- Context style: `full-rules-injected`
- Harness behavior:
  - copy the candidate worktree's original `AGENTS.md` to run artifacts
  - append every `.context/rules/*.md` file to worktree `AGENTS.md`
  - append `@AGENTS.md` to worktree `CLAUDE.md` for Claude Code runs
  - mark injected instruction files `skip-worktree` so normal candidate `git add -A` does not commit them
  - run the candidate
  - restore `AGENTS.md` and `CLAUDE.md` before diff capture
  - unset `skip-worktree` after restoration
  - keep injected `AGENTS.md` and metadata under the run artifact directory

Restoring instruction files before diff capture keeps grading focused on candidate task work, not the
harness-supplied context payload.

## Candidates

Use `stage-1c-candidates.tsv` as the manifest:

| Injected alias | Baseline alias | Platform/model |
|---|---|---|
| `cand-04-injected` | `cand-04` | claude-code / sonnet |
| `cand-05-injected` | `cand-05` | claude-code / haiku |
| `cand-06-injected` | `cand-06` | cursor / composer-2.5 |
| `cand-12-injected` | `cand-12` | claude-code / opus |
| `cand-13-injected` | `cand-13` | codex / gpt-5.4-mini |
| `cand-19-injected` | `cand-19` | copilot / auto |
| `cand-20-injected` | `cand-20` | cursor / auto |
| `cand-21-injected` | `cand-21` | gemini/agy / auto |

## Run Commands

Class A:

```bash
cd scripts/benchmark
MANIFEST="$PWD/../../.context/benchmarks/model-roi/stage-1c-candidates.tsv" \
make suite \
  TASK=opfit-281-class-a-premerge-context-injected \
  BASE=6946d04b3fd17014e32d9da5ea947acf6df14360 \
  STAGE=1 \
  CONTEXT_VARIANT=full-rules-injected
```

Class B:

```bash
cd scripts/benchmark
MANIFEST="$PWD/../../.context/benchmarks/model-roi/stage-1c-candidates.tsv" \
make suite \
  TASK=opfit-326-class-b-premerge-context-injected \
  BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6 \
  STAGE=1 \
  CONTEXT_VARIANT=full-rules-injected
```

## Analysis

Compare each injected result to its paired baseline alias:

```text
score_delta = injected_score - baseline_score
cost_delta  = injected_cost - baseline_cost
roi_delta   = injected_roi - baseline_roi
```

Track these context-specific fields:

- `context_variant`
- `injected_agents_bytes`
- `injected_agents_sha256`
- `input_token_delta`
- `wall_s_delta`
- `process_score_delta`
- `roi_delta`

## Interpretation

The injected variant wins only if score/process adherence improves enough to offset added input-token
cost and latency. If full-rule injection helps weaker agents but harms top-ROI agents, issue #376 should
favor role/task-specific context packs instead of a universal god-object `AGENTS.md`.
