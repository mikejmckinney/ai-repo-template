---
description: Produce the planning artifact for a two-phase model ROI benchmark run.
agent: agent
---

# Model ROI Duo Planner Prompt

> Canonical path: `.github/prompts/model-roi-duo-planner.md`
> Durable protocol surface: `.context/benchmarks/model-roi/stage-1d-duo-workflow.md`
> Benchmark subissue: `#374`

Use this exact prompt for the planner phase of each Stage 1D duo candidate.
Candidate-specific input is limited to the metadata block and injected task.

## Candidate run metadata

```yaml
candidate_alias: cand-<NN>-duo
candidate_platform: <copilot | cursor | claude-code | codex | gemini-cli>
planner_model: <exact model selected in the runtime, or "unknown - not exposed by runtime">
implementer_model: <exact model selected for implementation>
task_id: <taskid>
task_class: <A-operational | B-reasoning>
base_branch: benchmark/model-roi/base-<taskid>-YYYYMMDD
base_sha: <exact frozen base SHA>
run_index: <integer run number, usually 1>
candidate_branch: benchmark/model-roi/<taskid>-cand-<NN>-duo-r<run_index>
subissue: #374
```

## Objective

You are the **planner** in a controlled two-phase agent/model ROI benchmark.
Your job is to produce a concise, implementation-ready plan for the injected
task. A cheaper implementer model will execute the plan in a separate clean
worktree. The benchmark measures whether this separation improves ROI.

## Hard boundary

Do not edit repository files. Do not commit. Do not push. Do not open a PR.
This phase is plan-only.

If your runtime insists on touching files, revert or report the deviation in
the final plan artifact. The implementer starts from the frozen base, not from
planner edits.

## Required startup behavior

Follow the repository's normal startup instructions enough to plan responsibly.
At minimum:

1. Read `AGENTS.md`.
2. Read `.context/00_INDEX.md`.
3. Read `.context/rules/process_work_style.md`.
4. Read `.context/rules/process_gates.md`.
5. Read `.context/rules/process_pr_completion.md`.
6. Read `.context/rules/process_doc_maintenance.md`.
7. Read `.github/PLAN_TEMPLATE.md`.
8. Inspect the files named by the injected task before proposing edits.

If the runtime exposes an exact model name, report it in the final summary;
otherwise write
`unknown - not exposed by runtime`.

## Task

> The benchmark harness injects the task body below this heading.

## Planner output contract

Your final response must include exactly one implementation plan section
delimited by these markers:

```text
DUO_PLAN_START
...
DUO_PLAN_END
```

Inside the markers, include:

- `summary`: one short paragraph.
- `files_to_change`: exact expected paths and why.
- `implementation_steps`: ordered steps the implementer should follow.
- `verification_steps`: exact commands to run and expected signal.
- `scope_guards`: what not to change.
- `known_risks`: likely pitfalls and how to avoid them.
- `doc_sync_decision`: docs/check surfaces likely needed or explicitly not needed.
- `plan_following_note`: tell the implementer to record any deviation and why.

Keep the plan concise. Do not include reference-solution details; the reference
solution is sealed from candidates.
