<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks the currently-active task. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example.
     Re-read requirement: before rewriting this file, re-read AGENTS.md §"Session-state cadence". -->

# Active Task

**Active Task**: #220 Phase 2 — per-role model tiering (ADR-016) — plan revision posted, implementation not yet started
**File**: N/A
**Role**: architect (lead) — implementation will dispatch across docs / devops / qa
**Blockers**: None — awaiting kickoff
**Next 1–3 actions**:
1. Create Phase 2 implementation branch from `main`; draft ADR-016 with the 7 amendments and tier table
2. Update `.claude/agents/*.md` and `.github/agents/*.agent.md` with pinned `model:` per amendments #1 / #7 (VS Code docs verified 2026-05-02: `.agent.md` accepts `model:` field; ADR-016 supersedes ADR-003)
3. Add per-platform allowlists to `test.sh`; mark ADR-003 Superseded-by ADR-016
