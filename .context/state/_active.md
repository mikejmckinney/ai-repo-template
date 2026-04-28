<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example. -->

# Active Task

**Active Task**: #206 — PR completion criteria for interactive sessions
**File**: AGENTS.md, test.sh, .github/prompts/pr-resolve-all.md
**Role**: Docs
**Blockers**: None
**Next 1–3 actions**:
1. Open PR with plan link in body
2. Wait for CI + bot reviews; iterate per the new section
3. Update `latest_summary.md` at session end / task close-out (do not defer to merge per AGENTS.md §Session-state cadence); amend post-merge if outcome changes
