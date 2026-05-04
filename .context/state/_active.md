<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks the currently-active task. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example. -->

# Active Task

**Active Task**: #229 Phase 1 — shellcheck + shfmt + actionlint in lint-and-format.yml + pr-iteration-stats.sh metric script
**File**: N/A
**Role**: devops
**Blockers**: None
**Next 1–3 actions**:
1. Run `bash test.sh` to verify all assertions pass
2. Push PR #232 and verify CI passes
3. Address any remaining bot review feedback on PR #232
