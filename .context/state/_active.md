<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example. -->

# Active Task

**Active Task**: #150 — PR #218 awaiting re-review of bot-feedback fixes
**File**: PR #218 on `feat/150-postmortem-feedback-loop` (commit `45094e9`)
**Role**: docs (lead)
**Blockers**: None — Phase 1–4 of `pr-resolve-all.md` complete; all 10 bot threads resolved; awaiting re-review on push (#205/#217 workflow)
**Next 1–3 actions**:
1. Wait for re-review; if new findings, repeat `pr-resolve-all.md`
2. On clean re-review, await maintainer merge
3. After merge, close task and remove from `_active.md`
