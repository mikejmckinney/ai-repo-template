---
description: Run one pipeline alias in the controlled model ROI benchmark against a frozen base, aliased branch, and injected task.
agent: agent
---

# Model ROI Orchestration Pipeline Candidate Prompt

> Canonical path: `.github/prompts/model-roi-orchestration-pipeline-candidate.md`
> Durable protocol surface: `.context/benchmarks/model-roi/issue-376-orchestration-pipeline.md`
> Benchmark subissue: `#376`

Use this exact prompt for every issue #376 pipeline candidate run. Do not
customize the prompt body per candidate. Candidate-specific input is limited to
the run-metadata block and the injected task.

## Candidate run metadata

```yaml
candidate_alias: cand-<NN>-pipe
candidate_platform: <copilot | cursor | claude-code | gemini-cli>
candidate_model: <exact model selected in the runtime, or "unknown - not exposed by runtime">
candidate_agent: <agent/runtime name>
task_id: <taskid>
task_class: <A-operational | B-reasoning>
base_branch: benchmark/model-roi/base-<taskid>-YYYYMMDD
base_sha: <exact frozen base SHA>
run_index: <integer run number, usually 1>
candidate_branch: benchmark/model-roi/<taskid>-cand-<NN>-pipe-r<run_index>
subissue: #376
```

The evaluator records the alias-to-model mapping privately. Candidate branches
stay aliased so grading is blind.

## Objective

You are participating in a controlled **orchestrated-pipeline ROI benchmark**
for `mikejmckinney/ai-repo-template`.

Complete the injected task as a normal repository contributor would, but use the
repo's role-specialized subagent workflow when your runtime supports it. This
run measures the **whole pipeline**, including the parent/orchestrator, role
handoffs, review gates, implementation, verification, and any coordination
overhead needed to reach a verifiable candidate diff.

## Pipeline Scope Guard

1. Subagents and role handoffs are **enabled**. They are the system under test.
2. Keep orchestration proportional to the task. Do not dispatch unnecessary
   roles merely to inflate the appearance of coordination.
3. Do not change model-routing defaults, committed role files, ADR-019 tier
   mappings, or benchmark harness files.
4. Do not browse or research external pricing or the web. You are not
   responsible for computing cost; report raw telemetry only.
5. Do not edit secrets, token scopes, billing settings, or repository
   permissions.
6. No destructive git on shared branches. Never force-push `main` or the frozen
   base branch.
7. Do not push or open a PR from inside the benchmark harness. The runner owns
   push and PR creation.

## Required Startup Behavior

Follow the repository's normal startup instructions. At minimum:

1. Read `AGENTS.md`.
2. Read `AI_REPO_GUIDE.md`.
3. Read `.context/00_INDEX.md`.
4. Read `.context/rules/process_role_selection.md`.
5. Read `.context/rules/agent_ownership.md`.
6. Read `.context/rules/process_subagent_bootstrap.md`.
7. Read `.context/rules/process_work_style.md`.
8. Read `.context/rules/process_gates.md`.
9. Read `.context/rules/process_pr_completion.md`.
10. Read `.context/rules/process_doc_maintenance.md`.
11. Read `.context/rules/process_model_tier.md`.
12. Read `.github/PLAN_TEMPLATE.md`.
13. Check the current branch and repository status before editing.

If the runtime exposes an exact model name, report it in the final summary;
otherwise write
`unknown - not exposed by runtime`.

## Task

> **INJECTED PER ROUND.** The benchmark owner injects one task body from
> `.context/benchmarks/model-roi/tasks/<task-id>.md`.

## Required Implementation Plan

Before implementation, create a plan using `.github/PLAN_TEMPLATE.md`.

If GitHub issue commenting is available, post the plan on benchmark subissue
`#376`. Otherwise include the full plan in your final response under
`## Implementation plan that would be posted to #376`.

The plan must include:

```yaml
role_dispatch:
  decision: "pipeline"
  planned_subagents:
    - <role names you actually expect to use>
  monolithic_justification: "N/A - issue #376 measures orchestration as the unit under test."
  orchestration_cost_note: "Parent/orchestrator, role dispatches, review turns, and handoff artifacts all count toward benchmark cost."
```

Set `Model tier:` according to the candidate configuration, but do not change
repo model defaults.

## Recommended Pipeline Shape

Use the minimum role sequence that can honestly complete the task.

For simple operational Class A work, a reasonable pipeline is:

1. Analyst or Architect only if the scope is ambiguous.
2. DevOps implements script/check changes.
3. QA or Judge/Critic reviews the final diff when available.

For Class B reasoning/code work, a reasonable pipeline is:

1. Analyst validates acceptance criteria and task boundaries.
2. Architect designs the helper/check/doc approach.
3. DevOps implements shell/workflow/check changes.
4. QA verifies behavior and tests.
5. Critic and Judge review the final diff if the runtime supports those roles.

If your runtime cannot invoke native subagents, simulate the handoff explicitly
inside the same agent response and label it as `simulated-role-pass`; do not
claim native subagent evidence when none occurred.

## Required PR Artifact

Do **not** push, force-push, or open a PR from inside the benchmark harness. The
runner owns push/PR creation so candidate identity remains blind and branch
publication is deliberate.

Prepare the exact draft PR metadata the maintainer can use after the run:

- PR base: the frozen base branch from the metadata block, never `main`.
- PR head: the aliased candidate branch.
- PR title: `Benchmark <task_id>: <short task name> (<candidate_alias>)`
- Link the subissue with `Refs #376`, not `Closes`.
- Fill the PR template accurately; include verification results, doc-sync
  decisions, role dispatch evidence, and verifiable-artifact evidence.
- Do not request auto-merge.

Provide the exact candidate branch, final commit SHA, `git push` command, and
`gh pr create` command the maintainer can run.

## Verification Expectations

Run the most appropriate verification available:

```bash
./test.sh
```

Also run any task-specific checks the task body names. Do not author your own
pass/fail gate for the benchmark. The evaluator runs an independent acceptance
check. If `./test.sh` is slow or fails for unrelated pre-existing reasons, run
the narrowest relevant checks and explain the limitation.

Never claim a check passed unless it actually ran and passed.

## Final Response Requirements

```markdown
## Benchmark pipeline candidate summary

### Candidate
- Alias / Platform / Model / Agent-runtime:
- Task id / class:
- Base branch / Base SHA / Candidate branch:
- PR (or "local-only" + creation commands):
- Final commit SHA:

### Pipeline Result
- Status: <SUCCESS | PARTIAL | BLOCKED>
- Acceptance criteria met: <yes/no/partial>
- Verification run / result:
- Human intervention needed: <none | describe>

### Role Dispatch Evidence
- Native subagents used: <yes/no/partial>
- Roles invoked:
- Handoff artifacts produced:
- Role failures, stalls, or simulated-role passes:
- Parent/orchestrator work performed:

### Raw Usage Telemetry (for evaluator cost computation - do NOT compute dollars yourself)
- Input tokens / Output tokens / Cached tokens: <numbers or "unknown - not exposed by runtime">
- Per-role token/cost telemetry if exposed:
- Wall-clock minutes:
- Session cold or warm: <cold | warm | unknown>

### Verifiable-Artifact Evidence
- Local commit exists (SHA + `git show --stat`): <evidence>
- Branch on remote: <yes/no>   PR: <yes/no/url>
- PR autonomy: <maintainer-driven>

### Files Changed
- `path` - reason

### Process Compliance
- AGENTS.md instructions loaded:
- Plan posted-or-included:
- Subagents/handoffs used or explicitly unavailable:
- Ownership respected:
- PR template completed:
- Doc-sync decisions recorded:
- Pipeline scope guard honored:

### Known Deviations
- <none or list>

### Opportunity Notes
- <none or up to 3; do not expand scope>
```

## Acceptance Criteria For This Candidate Run

- [ ] Startup instructions followed and reported.
- [ ] Implementation plan posted or included with pipeline `role_dispatch`.
- [ ] Subagents/handoffs used where available, or unavailability reported
      honestly.
- [ ] Injected task deliverables implemented per its body, scope-controlled.
- [ ] Verification run with real, non-fabricated output.
- [ ] Draft PR metadata provided against the frozen base branch, or verifiable
      local commit plus exact PR-creation commands provided.
- [ ] Final response includes raw usage telemetry, timing, role dispatch
      evidence, verification, and verifiable-artifact evidence.
- [ ] No committed role model pins or benchmark harness files changed by the
      candidate.
