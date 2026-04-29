<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example. -->

# Active Task

**Active Task**: #205 — re-trigger Gemini & Copilot review on every push
**File**: N/A
**Role**: devops
**Blockers**: None
**Next 1–3 actions**:
1. Open PR with plan link in body
2. Live smoke after merge: set `REVIEW_ON_PUSH=true`, push to a test PR, confirm both bots re-review
3. Update `latest_summary.md` at session end / task close-out
