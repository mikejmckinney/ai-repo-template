<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks the currently-active task. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->
<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example.
     Re-read requirement: before rewriting this file, re-read AGENTS.md §"Session-state cadence". -->

# Active Task

**Active Task**: #226 PR4 — prompt frontmatter audit (decision artifact only)
**File**: `.context/state/task_226-pr4-prompt-frontmatter-audit.md`
**Role**: architect
**Blockers**: None
**Next 1–3 actions**:
1. Await merge of PR #239 (CI green, 0 unresolved bot threads — stop condition met)
2. File separate issue for Finding 5 (doc-sync rule for shared-prompt list)
3. Close out task_226-pr4 and update latest_summary.md
