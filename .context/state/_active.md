<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks the currently-active task. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example.
     Re-read requirement: before rewriting this file, re-read AGENTS.md §"Session-state cadence". -->

# Active Task

**Active Task**: #229 Phase 3 — pre-push Critic prompt (PR #244 open, awaiting human merge)
**File**: N/A
**Role**: DevOps
**Blockers**: None — bot loop converged (R4+R5 clean), all 9 threads resolved, CI green.
**Next 1–3 actions**:
1. Human merges PR #244 (or requests further changes)
2. After merge: remove Phase 3 lock from `coordination.md`
3. Phase 5 of #229 is comment-only; no further implementation queued
