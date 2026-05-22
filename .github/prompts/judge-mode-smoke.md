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
# PLAN-GATE required headings (must ALL be present — plain-text labels per .agents/judge.md)
grep -qE "^DECISION:" output.txt            && echo "OK: DECISION" || echo "FAIL: DECISION missing"
grep -qE "^WHY "       output.txt           && echo "OK: WHY" || echo "FAIL: WHY missing"
grep -qE "^REQUIRED CHANGES" output.txt     && echo "OK: REQUIRED CHANGES" || echo "FAIL: REQUIRED CHANGES missing"
grep -qE "^NICE-TO-HAVES"    output.txt     && echo "OK: NICE-TO-HAVES" || echo "FAIL: NICE-TO-HAVES missing"
grep -qE "^RISKS / GOTCHAS"  output.txt     && echo "OK: RISKS / GOTCHAS" || echo "FAIL: RISKS / GOTCHAS missing"
grep -qE "^TEST PLAN"        output.txt     && echo "OK: TEST PLAN" || echo "FAIL: TEST PLAN missing"
grep -qE "^QUESTIONS"        output.txt     && echo "OK: QUESTIONS" || echo "FAIL: QUESTIONS missing"

# DIFF-GATE exclusive headings (must ALL be absent — plain-text labels per .agents/judge.md)
grep -qE "^SUMMARY "         output.txt     && echo "FAIL: SUMMARY present (template blend)" || echo "OK: SUMMARY absent"
grep -qE "^MAJOR ISSUES"     output.txt     && echo "FAIL: MAJOR ISSUES present (template blend)" || echo "OK: MAJOR ISSUES absent"
grep -qE "^MINOR ISSUES"     output.txt     && echo "FAIL: MINOR ISSUES present (template blend)" || echo "OK: MINOR ISSUES absent"
grep -qE "^SUGGESTED PATCHES" output.txt    && echo "FAIL: SUGGESTED PATCHES present (template blend)" || echo "OK: SUGGESTED PATCHES absent"
grep -qE "^VALIDATION"       output.txt     && echo "FAIL: VALIDATION present (template blend)" || echo "OK: VALIDATION absent"
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
# DIFF-GATE required headings (must ALL be present — plain-text labels per .agents/judge.md)
grep -qE "^DECISION:" output.txt            && echo "OK: DECISION" || echo "FAIL: DECISION missing"
grep -qE "^SUMMARY "  output.txt            && echo "OK: SUMMARY" || echo "FAIL: SUMMARY missing"
grep -qE "^MAJOR ISSUES" output.txt         && echo "OK: MAJOR ISSUES" || echo "FAIL: MAJOR ISSUES missing"
grep -qE "^MINOR ISSUES" output.txt         && echo "OK: MINOR ISSUES" || echo "FAIL: MINOR ISSUES missing"
grep -qE "^SUGGESTED PATCHES" output.txt    && echo "OK: SUGGESTED PATCHES" || echo "FAIL: SUGGESTED PATCHES missing"
grep -qE "^VALIDATION"       output.txt     && echo "OK: VALIDATION" || echo "FAIL: VALIDATION missing"

# PLAN-GATE exclusive headings (must ALL be absent — plain-text labels per .agents/judge.md)
grep -qE "^WHY "             output.txt     && echo "FAIL: WHY present (template blend)" || echo "OK: WHY absent"
grep -qE "^REQUIRED CHANGES" output.txt     && echo "FAIL: REQUIRED CHANGES present (template blend)" || echo "OK: REQUIRED CHANGES absent"
grep -qE "^NICE-TO-HAVES"    output.txt     && echo "FAIL: NICE-TO-HAVES present (template blend)" || echo "OK: NICE-TO-HAVES absent"
grep -qE "^RISKS / GOTCHAS"  output.txt     && echo "FAIL: RISKS / GOTCHAS present (template blend)" || echo "OK: RISKS / GOTCHAS absent"
grep -qE "^TEST PLAN"        output.txt     && echo "FAIL: TEST PLAN present (template blend)" || echo "OK: TEST PLAN absent"
grep -qE "^QUESTIONS"        output.txt     && echo "FAIL: QUESTIONS present (template blend)" || echo "OK: QUESTIONS absent"
```

Expected: zero `FAIL:` lines.
