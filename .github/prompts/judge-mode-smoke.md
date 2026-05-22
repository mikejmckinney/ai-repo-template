---
mode: agent
description: No-edit smoke prompt for Judge PLAN-GATE/DIFF-GATE mode selection and output-format heading conformance.
---

# Judge Mode Selection & Output Format Smoke Test

No-edit smoke prompt. Do not modify this file.

## Purpose

Exercises both Judge modes with minimal fixtures and structural heading verification.
Pass criteria: structural heading verification — required headings present AND opposite-mode headings absent.

---

## Scenario A — Explicit plan-gate dispatch

**Dispatch**: `mode: plan-gate`

**Input payload**:

```
## Implementation Plan — Issue #999

### Outcome
A Judge receives explicit mode: plan-gate in its dispatch packet and selects PLAN-GATE mode.

### Files to change
- .agents/judge.md — one line edit
```

**Pass criteria**:

Run these grep checks on the Judge output. All must output `OK:`:
```bash
# PLAN-GATE required headings (must ALL be present)
grep -qE "^DECISION:" output.txt            && echo "OK: DECISION" || echo "FAIL: DECISION missing"
grep -qF "## Hard Requirements for Approval" output.txt && echo "OK: HardReq" || echo "FAIL: HardReq missing"
grep -qF "## Blocking Issues" output.txt    && echo "OK: Blocking" || echo "FAIL: Blocking missing"
grep -qF "## Required Changes" output.txt   && echo "OK: RequiredChanges" || echo "FAIL: RequiredChanges missing"
grep -qF "## Nice-to-Haves" output.txt      && echo "OK: NiceToHaves" || echo "FAIL: NiceToHaves missing"
grep -qF "## Risks / Gotchas" output.txt    && echo "OK: Risks" || echo "FAIL: Risks missing"
grep -qF "## Test Plan" output.txt          && echo "OK: TestPlan" || echo "FAIL: TestPlan missing"

# DIFF-GATE exclusive headings (must ALL be absent)
grep -qF "## Code Quality" output.txt       && echo "FAIL: DiffGate heading leaked" || echo "OK: no CodeQuality"
grep -qF "## Security Review" output.txt    && echo "FAIL: DiffGate heading leaked" || echo "OK: no SecurityReview"
grep -qF "## Breaking Changes" output.txt   && echo "FAIL: DiffGate heading leaked" || echo "OK: no BreakingChanges"
grep -qF "## Deployment Notes" output.txt   && echo "FAIL: DiffGate heading leaked" || echo "OK: no DeploymentNotes"
grep -qF "## Reviewer Notes" output.txt     && echo "FAIL: DiffGate heading leaked" || echo "OK: no ReviewerNotes"
```

Expected: zero `FAIL:` lines.

---

## Scenario B — Explicit diff-gate dispatch

**Dispatch**: `mode: diff-gate`

**Input payload**:

```
diff --git a/.agents/judge.md b/.agents/judge.md
index abc1234..def5678 100644
--- a/.agents/judge.md
+++ b/.agents/judge.md
@@ -54,7 +54,7 @@
-# Mode Selection
+# Mode Selection (Priority 1/2/3)
```

**Pass criteria**:

Run these grep checks on the Judge output. All must output `OK:`:
```bash
# DIFF-GATE required headings (must ALL be present)
grep -qE "^DECISION:" output.txt            && echo "OK: DECISION" || echo "FAIL: DECISION missing"
grep -qF "## Summary" output.txt            && echo "OK: Summary" || echo "FAIL: Summary missing"
grep -qF "## Code Review" output.txt        && echo "OK: CodeReview" || echo "FAIL: CodeReview missing"
grep -qF "## Security" output.txt           && echo "OK: Security" || echo "FAIL: Security missing"
grep -qF "## Test Coverage" output.txt      && echo "OK: TestCoverage" || echo "FAIL: TestCoverage missing"
grep -qF "## Required Changes" output.txt   && echo "OK: RequiredChanges" || echo "FAIL: RequiredChanges missing"

# PLAN-GATE exclusive headings (must ALL be absent)
grep -qF "## Hard Requirements for Approval" output.txt && echo "FAIL: PlanGate heading leaked" || echo "OK: no HardReq"
grep -qF "## Blocking Issues" output.txt    && echo "FAIL: PlanGate heading leaked" || echo "OK: no Blocking"
grep -qF "## Risks / Gotchas" output.txt    && echo "FAIL: PlanGate heading leaked" || echo "OK: no Risks"
grep -qF "## Test Plan" output.txt          && echo "FAIL: PlanGate heading leaked" || echo "OK: no TestPlan"
grep -qF "## Nice-to-Haves" output.txt      && echo "FAIL: PlanGate heading leaked" || echo "OK: no NiceToHaves"
grep -qF "## Nice to Haves" output.txt      && echo "FAIL: PlanGate heading leaked" || echo "OK: no NiceToHaves2"
```

Expected: zero `FAIL:` lines.
