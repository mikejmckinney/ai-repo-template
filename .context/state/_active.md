<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks the currently-active task. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example.
     Re-read requirement: before rewriting this file, re-read AGENTS.md §"Session-state cadence". -->

# Active Task

**Active Task**: #229 Phase 1.5 — PR #238 bot-review loop (Rounds 14–16 in progress)
**File**: N/A
**Role**: DevOps
**Blockers**: CLAUDE_PAT not injected in current VM (added to Cursor dashboard — available in next session). All Phase 3 reports + Phase 4 thread resolutions must be posted in next session.
**Next 1–3 actions**:
1. NEW SESSION: verify CLAUDE_PAT available, post all queued reports (see latest_summary.md), resolve fixed bot threads
2. After 2 clean rounds (no new actionable bot feedback), declare stopping condition met
3. If CI still green after reports posted: await merge
