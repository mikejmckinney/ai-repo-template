<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example. -->

# Active Task

**Active Task**: #150 — postmortem feedback loop v1 (capture + mirror prompts, ADR-015, postmortem-002 backfill)
**File**: docs/postmortems/, .github/prompts/capture-postmortem.md, .github/prompts/mirror-postmortem.md, docs/decisions/adr-015-postmortem-feedback-loop.md, AGENTS.md, test.sh
**Role**: docs (lead) + architect (ADR-015) + qa (test.sh invariants)
**Blockers**: None
**Next 1–3 actions**:
1. Commit + push branch `feat/150-postmortem-feedback-loop`
2. Open PR; link plan comment on #150
3. Address bot review feedback per `pr-resolve-all.md`; update `latest_summary.md` at task close-out
