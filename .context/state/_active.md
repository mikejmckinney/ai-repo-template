<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks all currently-active tasks (one section per branch). Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (multi-task; see ADR-018, including Amendment #1 — additive PR field):
     File header is fixed: `# Active Tasks`.
     Below the header, each in-flight branch owns one `## Task: <branch-name>` section.
     Per-section schema: Issue/PR | Role | PR | Blockers | Next 1–3 actions. Cap ~20 lines per section.
       - Backward-compat carve-out (ADR-018 Amendment #1): pre-amendment sections that predate the introduction of the `**PR**:` field may omit it and remain valid. New sections must include the field. Owners of pre-amendment sections may backfill at the next task-boundary edit on their own section, but no other agent may write into another's section. Validators MUST treat the field as optional on existing sections and required only on new ones.
       - Issue/PR: source issue number (`#NNN`) — what motivated the work.
       - PR: landing PR number (`#MMM`), `pending` (branch open, PR not yet created), or `N/A` (no PR planned). Cadence: write `pending` when the section is created (branch exists, PR not yet opened); update to `#MMM` at your next push *after* PR-open (PR numbers are only assigned by GitHub after creation, so the `pending` → `#MMM` update is a separate commit from the one that triggered PR creation); use `N/A` for branches that will not produce a PR. Mirrors the `**PR**:` field on the matching `coordination.md` lock.
     Agents edit ONLY their own section. Re-read the WHOLE file at every task boundary.
     Add a section when you claim a task; remove it as part of close-out (see .context/state/README.md "Cadence").
     Worked example (two parallel branches):

       # Active Tasks

       ## Task: feature/frontend-101-login-form
       **Issue/PR**: #101
       **Role**: frontend
       **PR**: #145
       **Blockers**: waiting on backend API contract (login-backend)
       **Next 1–3 actions**:
       1. Stub LoginForm component with form fields
       2. Wire up form validation
       3. Pause until login-backend lands

       ## Task: feature/backend-102-login-api
       **Issue/PR**: #102
       **Role**: backend
       **PR**: pending
       **Blockers**: None
       **Next 1–3 actions**:
       1. Define POST /login request/response schema
       2. Implement handler with bcrypt verify
       3. Open PR linking #102

     Re-read requirement: before rewriting your section, re-read AGENTS.md §"Session-state cadence". -->

# Active Tasks

## Task: feature/devops-262-make-closeout
**Issue/PR**: #262
**Role**: devops
**PR**: #268
**Blockers**: None
**Next 1–3 actions**:
1. Open PR with plan + verification (Makefile, closeout.sh, test-closeout.sh, test.sh wiring, doc updates)
2. Run pr-resolve-all.md loop with `cap-override` until two consecutive clean iterations
3. Open `chore(closeout): PR #NNN merged` follow-up PR after merge — dogfood `make closeout` to draft it

## Task: feature/devops-220-phase2
**Issue/PR**: #220 (Phase 2)
**Role**: devops (lead) + architect (ADR-019) + docs + qa
**Blockers**: None
**Next 1–3 actions**:
1. Implement Phase 2 file changes (ADR-019, 20 agent files, test.sh, AGENTS.md, PLAN_TEMPLATE.md, agent-pipeline.md)
2. Run `bash test.sh`; commit; push; open PR
3. Run pr-resolve-all.md loop with `cap-override` until two clean iterations

## Task: feature/architect-237-multi-task-active-md
**Issue/PR**: #237
**Role**: architect
**Blockers**: None
**Next 1–3 actions**:
1. Open PR with ADR-018 + schema migration + test harness + postmortem-003
2. Run pr-resolve-all.md loop until two clean iterations
3. Close out task; remove this section in the close-out commit

## Task: feature/architect-252-orchestration-patterns-reference
**Issue/PR**: #252 (parent #251)
**Role**: architect
**Blockers**: None
**Next 1–3 actions**:
1. Open PR shipping `.context/rules/repo_orchestration_patterns.md` + ADR-020 + wiring (AGENTS link, ownership row, critic/judge refs, test.sh assertion, doc-sync trigger row)
2. Run pr-resolve-all.md loop with `cap-override` until two clean iterations
3. Close out; remove this section in close-out commit

## Task: feature/architect-227-pre-merge-verification
**Issue/PR**: #227
**Role**: architect (planning) → devops + docs (this PR ships all three)
**Blockers**: None (sandbox repo creation deferred to maintainer manual step per playbook)
**Next 1–3 actions**:
1. Open PR shipping ADR-016 + verify-pr.sh + matrix + sandbox playbook + Phase-3 codification
2. Run pr-resolve-all.md loop with `cap-override` until two clean iterations
3. Close out; maintainer runs `gh repo create mikejmckinney/ai-repo-template-sandbox` per playbook
