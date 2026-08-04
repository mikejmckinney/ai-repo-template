# Stage 1D Duo Planner/Implementer Workflow

Issue: #374

Status: setup ready; benchmark runs pending.

## Question

Does a two-phase workflow improve model ROI when a stronger or auto-routed
planner creates an implementation plan and a cheaper or auto-routed implementer
executes it?

This stage is not a reasoning-effort sweep and not a full multi-agent pipeline.
It is a controlled duo workflow:

1. Planner phase: produce a plan artifact only.
2. Implementer phase: start from the same frozen base, consume the plan artifact,
   and produce the scored diff.

## Candidate Set

| Alias | Platform | Planner | Implementer | Primary comparison |
|---|---|---|---|---|
| `cand-12-duo` | claude-code | opus | haiku | `cand-12`, `cand-05`, `cand-05-agents`, `cand-05-injected` |
| `cand-14-duo` | codex | gpt-5.4 | gpt-5.4-mini | `cand-14`, `cand-13` |
| `cand-21-duo` | gemini/agy | auto | auto | `cand-21` |
| `cand-19-duo` | copilot | auto | auto | `cand-19` |
| `cand-20-duo` | cursor | auto | auto | `cand-20` |

## Protocol

- Use the same Class A and Class B task files as Stage 1:
  - `.context/benchmarks/model-roi/tasks/opfit-281-class-a-premerge.md`
  - `.context/benchmarks/model-roi/tasks/opfit-326-class-b-premerge.md`
- Use the same frozen base SHAs as the completed Stage 1 benchmark.
- Run candidates sequentially so wall time and quota pressure remain comparable.
- Store planner and implementer artifacts separately under each run directory:
  - `planner/agent-output.jsonl`
  - `planner/plan.md`
  - `implementer/agent-output.jsonl`
  - `diff.patch`
  - `meta-blind.json`
  - `meta-sealed.json`
- The planner worktree is separate from the implementer worktree. Planner edits,
  if any, are not part of the scored diff.
- The implementer must not dispatch additional agents. Stage 1D measures only
  planner artifact plus implementer execution, not recursive orchestration.

## Cost And ROI

Use the issue #374 cost formula with planner and implementer costs summed:

```text
duo_marginal_cost_usd = planner_marginal_cost_usd + implementer_marginal_cost_usd
duo_marginal_roi      = weighted_score / duo_marginal_cost_usd
```

Where telemetry exists, record:

- planner input/output/cached tokens,
- implementer input/output/cached tokens,
- planner wall seconds,
- implementer wall seconds,
- total wall seconds,
- model(s) actually routed when auto mode is used.

Do not hide planner cost. A cheap implementation phase is only useful if the
combined planner-plus-implementer cost improves ROI.

## Grading Notes

Use the same 100-point Class A/Class B rubric already used in
`docs/benchmarks/agent-roi-benchmark-results.md`:

- Correctness /30
- Code/doc quality /25
- Repo-process adherence /20
- Tool reliability /15
- Latency /10

Additional process evidence to capture for Stage 1D:

- Was the planner artifact present and usable?
- Did the implementer follow the plan?
- If the implementer deviated, was the deviation justified?
- Did the planner create repo edits despite the plan-only boundary?

These are not separate score columns; fold them into Process and Reliability.

## Commands

Class A example:

```bash
make duo-suite \
  TASK=opfit-281-class-a-premerge \
  BASE=6946d04b3fd17014e32d9da5ea947acf6df14360 \
  STAGE=1d
```

Class B example:

```bash
make duo-suite \
  TASK=opfit-326-class-b-premerge \
  BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6 \
  STAGE=1d
```

Single-candidate example:

```bash
make duo-run \
  TASK=opfit-281-class-a-premerge \
  BASE=6946d04b3fd17014e32d9da5ea947acf6df14360 \
  ALIAS=cand-12-duo
```

## Expected Result Reporting

Append Stage 1D rows to the existing results document:

- Class A/Class B score tables or a new Stage 1D subsection.
- Class A/Class B Marginal ROI tables, sorted by ROI.
- Raw telemetry rows showing planner and implementer token/cost components.
- Caveats for auto-routed candidates where the runtime reports routed models.
