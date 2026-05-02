<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example. -->

# Active Task

**Active Task**: #220 Phase 2 — per-role model tiering (ADR-016) — plan revision posted, implementation not yet started
**File**: issue #220 (Plan revision comment 4364362566); Phase 1 shipped via PR #223 (merged)
**Role**: architect (lead) — implementation will dispatch across docs / devops / qa
**Blockers**: None — awaiting kickoff
**Next 1–3 actions**:
1. Create Phase 2 implementation branch from `main`; draft ADR-016 with the 7 amendments and tier table
2. Update `.claude/agents/*.md` and `.github/agents/*.agent.md` with pinned `model:` per amendment #1 / #7
3. Add per-platform allowlists to `test.sh`; mark ADR-003 Superseded-by ADR-016
