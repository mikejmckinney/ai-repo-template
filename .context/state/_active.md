<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks all currently-active tasks (one section per branch). Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (multi-task; see ADR-018):
     File header is fixed: `# Active Tasks`.
     Below the header, each in-flight branch owns one `## Task: <branch-name>` section.
     Per-section schema: Issue/PR | Role | Blockers | Next 1–3 actions. Cap ~20 lines per section.
     Agents edit ONLY their own section. Re-read the WHOLE file at every task boundary.
     Add a section when you claim a task; remove it as part of close-out (see .context/state/README.md "Cadence").
     Worked example (two parallel branches):

       # Active Tasks

       ## Task: feature/frontend-101-login-form
       **Issue/PR**: #101
       **Role**: frontend
       **Blockers**: waiting on backend API contract (login-backend)
       **Next 1–3 actions**:
       1. Stub LoginForm component with form fields
       2. Wire up form validation
       3. Pause until login-backend lands

       ## Task: feature/backend-102-login-api
       **Issue/PR**: #102
       **Role**: backend
       **Blockers**: None
       **Next 1–3 actions**:
       1. Define POST /login request/response schema
       2. Implement handler with bcrypt verify
       3. Open PR linking #102

     Re-read requirement: before rewriting your section, re-read AGENTS.md §"Session-state cadence". -->

# Active Tasks

## Task: feature/devops-220-phase2
**Issue/PR**: #220 (Phase 2)
**Role**: devops (lead) + architect (ADR-016) + docs + qa
**Blockers**: None
**Next 1–3 actions**:
1. Implement Phase 2 file changes (ADR-016, 20 agent files, test.sh, AGENTS.md, PLAN_TEMPLATE.md, agent-pipeline.md)
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

## Task: feature/architect-227-pre-merge-verification
**Issue/PR**: #227
**Role**: architect (planning) → devops + docs (this PR ships all three)
**Blockers**: None (sandbox repo creation deferred to maintainer manual step per playbook)
**Next 1–3 actions**:
1. Open PR shipping ADR-016 + verify-pr.sh + matrix + sandbox playbook + Phase-3 codification
2. Run pr-resolve-all.md loop with `cap-override` until two clean iterations
3. Close out; maintainer runs `gh repo create mikejmckinney/ai-repo-template-sandbox` per playbook
