---
description: Implement Class C greenfield framework benchmark on benchmark/roi; defer Stage 1E CP-2.
agent: agent
---

# Prompt: Implement Class C greenfield framework benchmark and defer CP-2

You are implementing a benchmark-harness enhancement in `mikejmckinney/ai-repo-template`.

## Branch / starting point

Start from the long-lived **`benchmark/roi`** branch (created post–Phase A merge from tag
`benchmark/phase-a-artifacts-20260608`, then merged with `main`).

```bash
git fetch origin --tags
git checkout benchmark/roi
git pull --ff-only origin benchmark/roi
```

If `benchmark/roi` does not exist yet, stop and report — Phase A must merge to `main` and
the maintainer must create `benchmark/roi` from the fixture tag first.

If the branch cannot fast-forward because it diverged from `main`, **do not merge `main`
casually**. Report the divergence in your plan and keep this work scoped to `benchmark/roi`
unless the maintainer explicitly requests a rebase/merge.

## Goal

Implement the next benchmark stage as a **single-issue scope**:

1. Defer Stage 1E CP-2 robustness work for now.
2. Add a Class C greenfield app benchmark that tests agent/model ROI on a complete app built from scratch.
3. Add a framework comparison condition:
   - `ai-repo-template` with the best Class C context pack.
   - GitHub Spec Kit.
4. Keep the standardized canonical grading approach already added on this branch.
5. Keep the top-level 100-point benchmark rubric, but add Class C-specific objective checks and secondary framework-fit diagnostics.

Do **not** split this into a separate “document the plan” issue and an “implement the harness” issue. The plan and harness implementation belong in this one implementation PR.

## Required context

Before editing, read:

- `AGENTS.md`
- `.context/rules/process_session_start.md`
- `.context/rules/README.md`
- `.context/benchmarks/model-roi/README.md`
- `.context/benchmarks/model-roi/benchmark-runbook.md`
- `.context/benchmarks/model-roi/grading/README.md`
- `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md`
- `scripts/benchmark/Makefile`
- `scripts/benchmark/lib.sh`
- `scripts/benchmark/run-candidate.sh`
- `scripts/benchmark/grading_lib.py`
- `scripts/benchmark/grade-objective.py`
- `scripts/benchmark/prepare-grade-bundle.sh`
- `scripts/checks/167-context-pack-manifests.sh`
- `scripts/checks/168-benchmark-grading.sh`, if present

Also inspect the current tree for backup or placeholder artifacts before editing:

```bash
git ls-files | grep -E '(\.bak-|stage-.*responses|llm-responses|update-.*\.py)$' || true
```

If committed backup files, zero-byte scripts, or empty response JSON fixtures exist, either remove them if accidental or document why they are intentionally tracked. Do not add more generated benchmark run artifacts unless they are deliberate, minimal fixtures used by checks.

## External dependency: GitHub Spec Kit

This benchmark compares `ai-repo-template` against GitHub Spec Kit.

Before implementing the Spec Kit condition, verify the latest official Spec Kit usage from `https://github.com/github/spec-kit` and pin an explicit release tag or commit SHA for benchmark reproducibility.

The prompt may mention commands such as:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@<pinned-tag>
specify init <project> --integration <agent>
```

But you must verify the current CLI command names, supported integrations, and slash-command/skills behavior before finalizing implementation. Record the verified Spec Kit version, install command, and integration behavior in benchmark docs and sealed metadata. Do not use a floating latest version in benchmark runs.

## Naming

Use a new benchmark stage name:

```text
Stage 1F — Class C greenfield framework benchmark
```

Use `Class C` for the task class:

```text
C-greenfield
```

If existing helpers only accept `A-operational` or `B-reasoning`, update validation to accept `C-greenfield` for this new task type without breaking old A/B tasks.

## Implementation deliverables

### 1. Document CP-2 deferral and Class C replacement path

Update:

- `.context/benchmarks/model-roi/README.md`
- `.context/benchmarks/model-roi/benchmark-runbook.md`
- `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md` only if this repo keeps benchmark plans/results in one file; otherwise create a focused Stage 1F protocol doc.

Required content:

- CP-2 is **deferred**, not canceled.
- Reason: CP-1 did not show enough production-relevant benefit to spend on CP-2 before rules consolidation / AGENTS decomposition lands.
- CP-1 remains exploratory evidence.
- Class C greenfield benchmark becomes the next more informative test bed.
- CP-1/CP-2 context-pack tests may be rerun later after:
  - `AGENTS.md` decomposition / rule consolidation lands.
  - Class C acceptance tests and grading are stable.
  - Spec Kit comparison path is implemented.

Do not overclaim. Preserve the nuance:

- Class A: baseline lazy loading looked competitive / preferred on mean ROI.
- Class B: `pack:core-min` looked useful in CP-1, but context surfaces are changing.
- CP-2 should not drive production policy until rerun under stabilized context rules.

### 2. Add Class C task spec

Create:

```text
.context/benchmarks/model-roi/tasks/class-c-greenfield-app.md
```

The task should define a fixed greenfield app that is non-trivial but bounded. Suggested app:

```text
TaskBoard Lite — local team Kanban app
```

Minimum requirements:

- Predefined local users; no auth provider.
- Projects list.
- Kanban board per project.
- Tasks have title, description, assignee, status, due date, and comments.
- Status movement via drag/drop or explicit buttons.
- Current user can create/edit/delete own comments.
- Current user cannot edit/delete another user’s comments.
- Filter tasks by assignee and status.
- Persist state locally.
- Seed data on first run.
- Include tests and README quickstart.
- Include a brief architecture note.

Use a fixed stack unless there is a strong reason not to:

```text
Vite + React + TypeScript
Vitest
Playwright or Testing Library for at least one user-flow acceptance check
localStorage or another local deterministic persistence layer
```

Keep the stack local and deterministic. Do not require paid external services, hosted DBs, SaaS auth, or network APIs.

Add frontmatter fields consistent with existing task files. Include:

```yaml
task_class: C-greenfield
base_branch: benchmark/model-roi/base-class-c-greenfield-app-YYYYMMDD
```

Include a `## Candidate task` section and keep any reference/hidden evaluator details out of the candidate prompt.

### 3. Add Class C acceptance harness

Create a deterministic acceptance harness under one of these paths:

```text
scripts/benchmark/class-c/
```

Suggested files:

```text
scripts/benchmark/class-c/README.md
scripts/benchmark/class-c/app-acceptance.sh
scripts/benchmark/class-c/package-smoke.sh
scripts/benchmark/class-c/playwright-taskboard-lite.spec.ts
scripts/benchmark/class-c/expected-artifacts.json
```

Acceptance checks should verify:

- project installs dependencies
- build succeeds
- unit tests pass
- app can start locally
- required UI flows are present:
  - user selection or active user indicator
  - project list
  - board view
  - create task
  - move task status
  - add comment
  - edit/delete own comment
  - cannot edit/delete another user's comment
  - filter by assignee or status
  - state persists after reload
- README quickstart exists
- architecture note exists

The acceptance harness must be designed to run against a generated candidate app in an isolated worktree. Avoid assumptions about exact component names or file layout unless required by the task spec.

### 4. Add Class C grading spec

Create:

```text
.context/benchmarks/model-roi/grading/tasks/class-c-greenfield-app.json
```

Keep the same top-level categories:

```text
Correctness / acceptance: 30
Code / doc quality: 25
Repo-process adherence: 20
Reliability / verification: 15
Latency: 10
```

Use a Class C-specific objective/subjective split. Recommended:

```text
Correctness: 25 objective / 5 subjective
Quality: 10 objective / 15 subjective
Process: 15 objective / 5 subjective
Reliability: 12 objective / 3 subjective
Latency: 10 objective / 0 subjective
Total: 72 objective / 28 subjective
```

If this split requires schema or script changes, implement them generically so each task grading JSON can define its own objective/subjective ceilings.

Do not change the top-level 100-point shape in `rubric.v1.json` unless required by the existing implementation design. Prefer task-specific objective ceiling configuration.

### 5. Add secondary framework-fit diagnostics

Do not add framework-fit points into the primary 100-point score yet. Add secondary diagnostics to the final grade or a sidecar.

Suggested fields:

```json
{
  "framework_fit": {
    "framework_condition": "ai-repo-template|spec-kit",
    "spec_artifact_completeness": 0,
    "implementation_traceability": 0,
    "human_steering_burden": 0,
    "generated_artifact_noise": 0,
    "rerun_continuation_support": 0,
    "notes": []
  }
}
```

These diagnostics answer whether Spec Kit or ai-repo-template creates better planning/traceability artifacts without biasing the primary app-quality score.

### 6. Add framework condition support

Add a benchmark concept:

```text
FRAMEWORK_CONDITION=ai-repo-template|spec-kit
```

or an equivalent `FRAMEWORK_VARIANT`.

Requirements:

- It must be recorded in sealed metadata.
- Blind grading bundles should not reveal the framework condition as a field.
- If the diff itself makes the framework obvious, that is acceptable, but do not leak labels like `spec-kit` in `meta-blind.json` or grading sheets.
- Include a neutral condition alias in blind metadata if useful:
  - `framework_condition_alias: fw-cond-001`

For `ai-repo-template` condition:

- Use a Class C context pack, initially `pack:class-c-greenfield`.
- Add manifest:

```text
.context/benchmarks/model-roi/context-packs/class-c-greenfield.tsv
```

Candidate contents after rules consolidation may change, but start with a bounded pack such as:

```text
.context/00_INDEX.md
.context/rules/agent_ownership.md
.context/rules/process_work_style.md
.context/rules/domain_code_quality.md
.context/rules/process_doc_maintenance.md
.context/rules/process_pr_completion.md
.context/sessions/latest_summary.md
```

For `spec-kit` condition:

- Bootstrap Spec Kit in the candidate worktree before the agent run.
- Use a pinned Spec Kit release/tag/SHA.
- Record:
  - install command
  - pinned version/tag/SHA
  - integration selected
  - generated Spec Kit artifact paths
  - whether commands/slash skills are available in the runtime
- The candidate prompt should instruct the agent to use the Spec Kit workflow:
  - constitution/principles
  - specify
  - clarify if needed
  - plan
  - tasks
  - implement

Do not let Spec Kit use a different app spec or stack than the ai-repo-template condition.

### 7. Add model/candidate manifests

Add example manifests for Stage 1F. Suggested path:

```text
.context/benchmarks/model-roi/stage-1f-class-c-candidates.tsv.example
```

Candidate set:

1. Cursor Composer 2.5
2. Gemini/agy Auto
3. Gemini Flash requested / observed backend recorded
4. Gemini 3.1 Flash Lite
5. Copilot Auto

Each candidate is run under both framework conditions:

```text
candidate × ai-repo-template class-c context pack
candidate × Spec Kit
```

You may represent framework condition through `RUN_GROUP` / runner variables rather than duplicating aliases, but final artifacts must let the operator distinguish the two conditions after unseal.

Recommended alias shape if duplicating rows:

```text
c3-cur-ait
c3-cur-spec
c3-gem-auto-ait
c3-gem-auto-spec
c3-gem-flash-ait
c3-gem-flash-spec
c3-gem-lite-ait
c3-gem-lite-spec
c3-cop-auto-ait
c3-cop-auto-spec
```

If using duplicated aliases, ensure the grader does not see suffixes that reveal framework condition. Use neutral eval IDs in grade bundles.

### 8. Gemini model verification

Implement or document a pre-spend model verification probe for fixed Gemini rows.

Problem to address:

- Prior Stage 1E requested `gemini-3.5-flash`, but observed `gemini-3-flash-preview`.
- Future fixed-model rows must distinguish requested alias from observed backend.

Requirements:

- Add a doctor/probe helper or runbook procedure for Gemini:
  - run a minimal prompt with `--output-format json`
  - save `.stats.models`
  - verify expected model id / alias mapping
  - record observed backend in sealed metadata
- If a literal `gemini-3.5-flash` model id cannot be verified, name the candidate as:
  - `Gemini Flash requested; observed backend recorded`
  not as a confirmed `gemini-3.5-flash` run.
- Verify `gemini-3.1-flash-lite` before scoring as fixed-model.

Do not hard-code stale assumptions. Make model verification evidence auditable.

### 9. Update runner/docs without running paid candidate benchmarks

This implementation PR should add harness/docs/specs/checks. It should not run the full paid Class C candidate matrix unless explicitly requested.

Allowed non-metered validation:

- syntax checks
- JSON schema validation
- manifest validation
- dry-run Spec Kit bootstrap with `--help` or no candidate LLM invocation
- acceptance-harness self-test against a small fixture app if feasible

Do not call paid LLM candidate agents as part of the implementation PR.

### 10. Update benchmark runbook

Add a runbook section:

```text
Stage 1F — Class C greenfield framework benchmark
```

Include:

- one-time setup
- freeze base
- install/pin Spec Kit
- verify integrations
- verify Gemini model ids
- run ai-repo-template condition
- run Spec Kit condition
- collect
- prepare grade bundles
- objective grade
- subjective grade
- compile
- unseal
- update results
- compare framework conditions

Add a recommended phased execution:

```text
Phase 0: harness validation with one cheap candidate
Phase 1: 5 candidates × 2 framework conditions once
Phase 2: repeat only finalists / unstable cells
```

### 11. Add checks

Add or update checks so `./test.sh` validates:

- Class C task spec exists and has candidate body.
- Class C grading spec validates against grading schema.
- Class C context pack manifest validates.
- Stage 1F candidate manifest example validates.
- No Spec Kit generated run artifacts are accidentally committed.
- No benchmark run artifacts under `scripts/benchmark/runs/` are tracked.
- Grading scripts still pass schema checks.
- Bash scripts pass `bash -n`.
- Python scripts import or run `--help` without syntax errors, if existing project checks support this.

If existing checks do not cover `scripts/benchmark/*.py`, add lightweight syntax/import validation for benchmark Python scripts.

### 12. Branch hygiene

Before final response, run:

```bash
git status --short
git diff --stat
git grep -n "CP-2" .context/benchmarks/model-roi .github/prompts || true
git grep -n "Class C" .context/benchmarks/model-roi scripts/benchmark .github/prompts || true
bash -n scripts/benchmark/*.sh scripts/benchmark/adapters/*.sh scripts/checks/*.sh
python3 -m py_compile scripts/benchmark/*.py
./test.sh
```

If `./test.sh` cannot run in the environment, run the most relevant checks directly and state what could not be run.

## Non-goals

Do not implement these in this PR:

- Full CP-2 paid benchmark run.
- Full Class C paid benchmark run.
- Production routing policy changes.
- Spec Kit migration decision.
- Review-bot timing workflow changes.
- AGENTS/rules decomposition beyond what is already in the branch.
- ADR amendments declaring ai-repo-template or Spec Kit the winner.

## Final response format for the agent

When finished, report:

```markdown
## Summary
- ...

## Files changed
- ...

## Validation
- [command] — result
- [command] — result

## Deferred / not run
- Full paid benchmark run not executed.
- Spec Kit model/agent runtime not invoked with paid candidate sessions.

## Notes for operator
- How to run Stage 1F Phase 0.
- How to run full Stage 1F Phase 1.
- How to regrade and compile results.
```

## Acceptance criteria

The implementation is complete when:

- [ ] CP-2 is documented as deferred in the benchmark docs/runbook.
- [ ] Class C greenfield task spec exists.
- [ ] Class C acceptance harness exists.
- [ ] Class C grading task spec exists.
- [ ] Class C context pack manifest exists.
- [ ] Stage 1F candidate manifest example exists.
- [ ] Framework condition support exists or is clearly documented in a runnable wrapper.
- [ ] Spec Kit bootstrap is pinned and auditable.
- [ ] Gemini model verification is documented or implemented.
- [ ] Blind grading does not leak framework/context labels via metadata fields.
- [ ] Standard 100-point scoring remains intact.
- [ ] Framework-fit diagnostics are secondary, not part of primary score.
- [ ] Tests/checks pass or failures are explicitly documented.
