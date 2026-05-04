<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks the currently-active task. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example.
     Re-read requirement: before rewriting this file, re-read AGENTS.md §"Session-state cadence". -->

# Active Task

**Active Task**: #229 Phase 2 — behavioral rules + external-reviewer gate alignment
**File**: N/A
**Role**: devops
**Blockers**: none
**Next 1–3 actions**:
1. Run `bash test.sh` to verify no regressions
2. Push fixes for ISS-01 through ISS-07 from PR #235 round 1
3. Monitor CI and bot re-reviews
