---
description: Implement a task from a supplied planner artifact in a two-phase model ROI benchmark run.
agent: agent
---

# Model ROI Duo Implementer Prompt

> Canonical path: `.github/prompts/model-roi-duo-implementer.md`
> Durable protocol surface: `.context/benchmarks/model-roi/stage-1d-duo-workflow.md`
> Benchmark subissue: `#374`

Use this exact prompt for the implementation phase of each Stage 1D duo
candidate. Candidate-specific input is limited to metadata, the injected task,
and the planner artifact produced in phase 1.

## Candidate run metadata

```yaml
candidate_alias: cand-<NN>-duo
candidate_platform: <copilot | cursor | claude-code | codex | gemini-cli>
planner_model: <exact planner model selected in the runtime, or "unknown - not exposed by runtime">
implementer_model: <exact implementer model selected in the runtime, or "unknown - not exposed by runtime">
task_id: <taskid>
task_class: <A-operational | B-reasoning>
base_branch: benchmark/model-roi/base-<taskid>-YYYYMMDD
base_sha: <exact frozen base SHA>
run_index: <integer run number, usually 1>
candidate_branch: benchmark/model-roi/<taskid>-cand-<NN>-duo-r<run_index>
subissue: #374
```

## Objective

You are the **implementer** in a controlled two-phase agent/model ROI benchmark.
Use the supplied planner artifact as your primary design input, then implement
the injected task as a normal repository contributor would.

The evaluator compares the final diff against monolithic baselines. The
planner and implementer costs are summed externally, so report raw usage
telemetry if your runtime exposes it. Do not compute dollars.

## Plan-following rule

Follow the supplied plan unless it is impossible, unsafe, or contradicts the
repository instructions. Do not re-architect from scratch merely because you
would have chosen a different path. If you deviate, record:

- the plan item you changed,
- the reason,
- the files affected.

## Benchmark isolation rules

1. Do not use subagents or delegate to another model.
2. Do not browse or research external pricing or the web.
3. Do not push, force-push, open a PR, or auto-merge.
4. Do not edit secrets, token scopes, billing settings, repository permissions,
   model-routing defaults, or benchmark harness files.
5. Keep the diff focused on the injected task.

## Required startup behavior

Follow the repository's normal startup instructions. At minimum:

1. Read `AGENTS.md`.
2. Read `.context/00_INDEX.md`.
3. Read `.context/rules/process_work_style.md`.
4. Read `.context/rules/process_gates.md`.
5. Read `.context/rules/process_pr_completion.md`.
6. Read `.context/rules/process_doc_maintenance.md`.
7. Read `.context/rules/process_model_tier.md`.
8. Read `.github/PLAN_TEMPLATE.md`.
9. Check the current branch and repository status before editing.

If the runtime exposes an exact model name, report it in the final summary;
otherwise write
`unknown - not exposed by runtime`.

## Task

> The benchmark harness injects the task body below this heading.

## Planner artifact

> The benchmark harness injects the planner artifact below this heading.

## Required implementation plan

Before implementation, create a brief plan using `.github/PLAN_TEMPLATE.md`.
It may reference the supplied planner artifact instead of duplicating every
detail. If GitHub issue commenting is available, post the plan on benchmark
subissue `#374`; otherwise include it in your final response.

The plan must include:

```yaml
role_dispatch:
  decision: "duo-implementer"
  planned_subagents: []
  monolithic_justification: "Stage 1D measures a two-phase planner/implementer workflow; implementation phase must not dispatch additional agents."
  duo_plan_source: "planner artifact supplied by benchmark harness"
```

## Required PR artifact

Do not push or open a PR. The runner owns push/PR creation so candidate identity
remains blind.

Prepare the exact draft PR metadata the maintainer can use after the run:

- PR base: the frozen base branch from the metadata block, never `main`.
- PR head: the aliased candidate branch.
- PR title: `Benchmark <task_id>: <short task name> (<candidate_alias>)`
- Link the subissue with `Refs #374`, not `Closes`.
- Fill the PR template accurately; include verification results, doc-sync
  decisions, plan-following evidence, and verifiable-artifact evidence.

## Verification expectations

Run the most appropriate verification available:

```bash
./test.sh
```

Also run any task-specific checks named in the task body. Never claim a check
passed unless it actually ran and passed.

## Final response requirements

```markdown
## Benchmark duo implementer summary

### Candidate
- Alias / Platform / Planner model / Implementer model:
- Task id / class:
- Base branch / Base SHA / Candidate branch:
- PR (or "local-only" + creation commands):
- Final commit SHA:

### Result
- Status: <SUCCESS | PARTIAL | BLOCKED>
- Acceptance criteria met: <yes/no/partial>
- Verification run / result:
- Human intervention needed: <none | describe>

### Plan following
- Planner artifact used: <yes/no>
- Deviations from supplied plan: <none or list>
- Reason for any deviation:

### Raw usage telemetry
- Input tokens / Output tokens / Cached tokens: <numbers or "unknown - not exposed by runtime">
- Wall-clock minutes:
- Session cold or warm: <cold | warm | unknown>

### Verifiable-artifact evidence
- Local commit exists (SHA + `git show --stat`): <evidence>
- Branch on remote: <yes/no>   PR: <yes/no/url>
- PR autonomy: <maintainer-driven>

### Files changed
- `path` - reason

### Process compliance
- AGENTS.md instructions loaded / Plan posted-or-included / Additional agents used: no /
  Duo plan followed-or-deviation-recorded / PR template completed /
  Doc-sync decisions recorded / Scope guard honored: <yes/no each>

### Known deviations
- <none or list>
```
