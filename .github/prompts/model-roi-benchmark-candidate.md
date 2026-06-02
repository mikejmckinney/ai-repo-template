---
description: Run one alias in the controlled model ROI benchmark against a frozen base, aliased branch, and injected task.
agent: agent
---

# Model ROI Benchmark Candidate Prompt

> Canonical path: `.github/prompts/model-roi-benchmark-candidate.md`
> Use this exact prompt for every candidate run. Do not customize the prompt body per candidate.
> Provide only the run-metadata block and the injected task as candidate-specific input.
> The durable benchmark protocol and reporting templates live under `.context/benchmarks/model-roi/`.
> Current repo scope: issue `#374` Phase A / Core Stage 1 only. Extended Stage 1 rows, all Stage 2 sweeps, and any ADR-019 routing changes are deferred to Phase B / Plan v2.

## Candidate run metadata

```yaml
candidate_alias: cand-<NN>            # neutral alias; do NOT reveal platform/model in branch names
candidate_platform: <copilot | cursor | claude-code | codex | gemini-cli>
candidate_model: <exact model selected in the runtime, or "unknown — not exposed by runtime">
candidate_agent: <agent/runtime name>
task_id: <taskid>
task_class: <A-operational | B-reasoning>
base_branch: benchmark/model-roi/base-<taskid>-YYYYMMDD
base_sha: <exact frozen base SHA>
run_index: <integer run number, usually 1>
candidate_branch: benchmark/model-roi/<taskid>-cand-<NN>-r<run_index>
subissue: #<benchmark subissue number>
```

> The evaluator records the alias→model mapping privately. You will report your model in the handshake and final summary for the evaluator's sealed record, but candidate branches stay aliased so grading is blind.

## Objective

You are participating in a controlled agent/model ROI benchmark for `mikejmckinney/ai-repo-template`.

Complete the **injected task** (see `## Task`) as a normal repository contributor would, while preserving repo process requirements and producing a verifiable draft PR or, if your runtime cannot open PRs, a verifiable local commit plus the exact commands to create one.

This is a benchmark. Work carefully, but do not expand scope. The evaluator compares your result, blind against a known-good reference solution, to other candidates given the same task, base commit, branch structure, and rubric.

## Phase A scope guard

For the current repo-owned benchmark rollout:

1. Work only inside **Phase A / Core Stage 1**.
2. Do **not** start extended Stage 1 harness-effect rows or any Stage 2 sweep/rerun.
3. Do **not** alter the prompt body to emulate different effort tiers. Stage 1 effort is controlled by the benchmark owner or harness: target `medium` where the runtime exposes a control; Cursor is recorded as `medium (requested)`.
4. If the injected task or operator instructions ask you to widen scope into Stage 2, stop and report the mismatch instead of guessing.

## Benchmark isolation rules

1. **No subagents or delegation to another model/agent.** This run measures the selected candidate only. Document this in your plan and PR compliance sections as:
   `monolithic_justification: Controlled benchmark isolation; subagent delegation would confound model/platform scoring.`
2. **No auto-merge.**
3. **No `claude-fix`, `copilot-relay`, `auto-merge`, or other automation labels** unless explicitly instructed by the benchmark owner.
4. **Do not change model-routing defaults, role files, or ADR-019 tier mappings.**
5. **Do not edit secrets, token scopes, billing settings, or repository permissions.**
6. **No destructive git on shared branches.** Never force-push `main` or the frozen base branch.
7. **Do not browse or research external pricing or the web.** This is a repository implementation benchmark, not a research task. Use only repo-local context unless a repo instruction explicitly requires otherwise. **You are not responsible for computing cost**. Report raw usage telemetry only; the evaluator converts telemetry to dollars later.
8. **Keep the diff small and focused.** Record adjacent issues as Opportunity notes; do not expand scope.

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

Emit the AGENTS.md session handshake. If the runtime exposes an exact model name, report it in the handshake and final summary; otherwise write `unknown — not exposed by runtime`.

## Task

> **INJECTED PER ROUND.** The benchmark owner pastes the specific task here or links it.
> The task is drawn from a closed issue that has a merged reference PR, so the evaluator has ground truth to grade against. The reference PR is **not** included in this prompt.
>
> Two task classes are used across the benchmark:
> - **Class A — operational fit:** convention/process adherence, docs, small file plus lightweight check.
> - **Class B — reasoning / code:** real bug fix or feature in existing logic, with tests.
>
> Replace this block with the task body for the current round. An example Class A task is in the appendix to illustrate the expected shape and constraints.

## Required implementation plan

Before implementation, create a plan using `.github/PLAN_TEMPLATE.md`.

If GitHub issue commenting is available, post the plan on the benchmark subissue. Otherwise include the full plan in your final response under `## Implementation plan that would be posted to #<subissue>`.

The plan must include:

```yaml
role_dispatch:
  decision: "monolithic"
  planned_subagents: []
  monolithic_justification: "Controlled benchmark isolation; subagent delegation would confound model/platform scoring."
```

Set `Model tier:` according to the model selected for this candidate, but do not change repo model defaults.

## Required PR Artifact

Do **not** push, force-push, or open a PR from inside the benchmark harness. The
runner owns push/PR creation so candidate identity remains blind and branch
publication is deliberate.

Prepare the exact draft PR metadata the maintainer can use after the run:

- PR base: the frozen base branch from the metadata block, never `main`.
- PR head: the aliased candidate branch.
- PR title: `Benchmark <task_id>: <short task name> (<candidate_alias>)`
- Link the subissue with `Refs #<subissue>`, not `Closes`.
- Fill the PR template accurately; include verification results, doc-sync decisions, and verifiable-artifact evidence.
- Do not request auto-merge.

Provide the exact candidate branch, final commit SHA, `git push` command, and
`gh pr create` command the maintainer can run. The result is gated on the work
being verifiable to exist, not on autonomous push.

## Verification expectations

Run the most appropriate verification available:

```bash
./test.sh
```

Also run any task-specific checks the task body names. Do **not** author your own pass/fail gate for the benchmark. The evaluator runs an independent acceptance check. If `./test.sh` is slow or fails for unrelated pre-existing reasons, run the narrowest relevant checks and explain the limitation.

**Never claim a check passed unless it actually ran and passed.** Fabricated results are a hard-gate failure.

## Final response requirements

```markdown
## Benchmark candidate summary

### Candidate
- Alias / Platform / Model / Agent-runtime:
- Task id / class:
- Base branch / Base SHA / Candidate branch:
- PR (or "local-only" + creation commands):
- Final commit SHA:

### Result
- Status: <SUCCESS | PARTIAL | BLOCKED>
- Acceptance criteria met: <yes/no/partial>
- Verification run / result:
- Human intervention needed: <none | describe>

### Raw usage telemetry  (for evaluator cost computation — do NOT compute dollars yourself)
- Input tokens / Output tokens / Cached tokens: <numbers or "unknown — not exposed by runtime">
- Wall-clock minutes:
- Session cold or warm: <cold | warm | unknown>

### Verifiable-artifact evidence
- Local commit exists (SHA + `git show --stat`): <evidence>
- Branch on remote: <yes/no>   PR: <yes/no/url>
- PR autonomy: <autonomous | maintainer-driven>

### Files changed
- `path` — reason

### Process compliance
- AGENTS.md handshake emitted / Plan posted-or-included / Subagents used: no /
  Monolithic justification recorded / PR template completed / Doc-sync decisions recorded /
  Phase A scope guard honored: <yes/no each>

### Known deviations
- <none or list>

### Opportunity notes
- <none or up to 3; do not expand scope>
```

## Acceptance criteria for this candidate run

- [ ] Startup instructions followed and reported (handshake emitted).
- [ ] Implementation plan posted or included, with the monolithic `role_dispatch` block.
- [ ] No subagents or other model delegation used.
- [ ] Injected task deliverables implemented per its body, scope-controlled.
- [ ] Verification run with real, non-fabricated output.
- [ ] Draft PR opened against the frozen base branch, **or** verifiable local commit plus exact PR-creation commands provided.
- [ ] Final response includes raw usage telemetry, timing, verification, and verifiable-artifact evidence.
- [ ] Phase A scope guard honored; no Stage 2 or extended Stage 1 work started.

## Appendix — Example task (Class A, operational fit)

> Illustrative only. In a real round the owner injects a task drawn from a closed issue with a merged reference PR. Do not implement this appendix unless it is pasted into `## Task`.

**Task:** Add a `scripts/checks/verify-deployment-configs.sh` check that confirms each deployment template referenced in `AI_REPO_GUIDE.md` has a corresponding config file present, and wire it into the existing check harness.

- Read the deployment-config catalog in `AI_REPO_GUIDE.md`.
- Add the check using the existing `scripts/checks/` pattern; do not add heavyweight dependencies.
- If the harness auto-discovers checks, state that in PR verification instead of modifying it; if it must be updated, update it minimally.
- Update `docs/guides/` only if doc-sync rules require it; record the decision in the PR.
- Keep the diff confined to the check, its harness wiring, and any required doc-sync.
- Open a draft PR to the frozen base branch and report verification output.

Reference grading material stays with the evaluator and is not shown here.
