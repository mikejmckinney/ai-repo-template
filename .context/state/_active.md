<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks the currently-active task. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example.
     Re-read requirement: before rewriting this file, re-read AGENTS.md §"Session-state cadence". -->

# Active Task

**Active Task**: #229 Phase 3 — pre-push Critic prompt + role-file SHOULD/MUST wiring (PR #244 open)
**File**: N/A
**Role**: DevOps
**Blockers**: None
**Next 1–3 actions**:
1. Open PR linking issue #229 (Phase 3 of 5)
2. Run `pr-resolve-all.md` against the PR; loop until two clean iterations under `cap-override`
3. Close out + update latest_summary.md after merge
