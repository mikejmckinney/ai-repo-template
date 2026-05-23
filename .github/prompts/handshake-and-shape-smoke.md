---
agent: agent
description: No-edit smoke prompt for session handshake positional contract and response-shape verification. Tests parent vs subagent handshake positioning, exact-output first-line contract, and receipt-section placement.
---

# Handshake & Shape Smoke Test

No-edit smoke prompt. Do not modify this file.

## Purpose

Exercises four response-shape scenarios: parent handshake positioning,
non-exact-output subagent shape, Judge plan-gate exact-output contract, and
Critic plan-gate exact-output contract. Pass criteria use **structural
position checks** for section ordering; field content within sections is
verified with grep. A required token at the wrong position is a FAIL even
if the word appears somewhere in the response.

## How to run

These are **manual verification prompts**, not automated test cases. To verify
a scenario:

1. Open a new agent session and give the agent the scenario's dispatch context.
2. Capture the agent's full response text to a file named `output.txt`.
3. Run the bash blocks in the corresponding "Pass criteria" section against that
   file — e.g., `bash < <(cat <<'EOF' ... EOF)` or paste each command into a
   terminal with `output.txt` in the working directory.
4. Confirm zero `FAIL:` lines.

Automated positional coverage is provided by
`scripts/tests/fixtures/compliance/valid/subagent-compliance-trailing-block.yml`
(validates the trailing-block receipt schema path).

---

## Scenario A — Parent agent handshake position

**Context**: Default agent (OP role) emitting its first substantive response
in a new session.

**Expected shape**:

1. `Session handshake v<N>` token is the LITERAL FIRST LINE of the response.
2. A 7-field table follows immediately (includes `Dispatch mode` and `Read profile` rows).
3. A `## Session context receipt` section appears in the response body.

**Pass criteria**:

```bash
# Line 1 must start with "Session handshake v<N>" with a concrete version number
head -1 output.txt | grep -qE "^Session handshake v[0-9]+" \
  && echo "OK: handshake is first line with concrete version" \
  || echo "FAIL: handshake is not first line or has no concrete version"

# Handshake table must follow token immediately (no intervening narrative)
awk '
  NR==1 && /^Session handshake/{hs=1; next}
  hs && /^[[:space:]]*$/{next}
  hs && /^\|/{tbl=1; hs=0}
  hs && NF>0{intervening=NR; hs=0}
  END{
    if (tbl && !intervening) print "OK: handshake table follows token with no intervening content";
    else if (intervening) print "FAIL: non-table content on line " intervening " between handshake token and table";
    else print "FAIL: no table row found after handshake token"
  }
' output.txt

# 7-field table must include all required rows (scoped to handshake table)
awk 'NR==1 && /^Session handshake/{hs=1} hs && /\| *Agent *\|/{ag=1} hs && /\| *Role *\|/{ro=1} hs && /\| *Model *\|/{mo=1} hs && /\| *AGENTS\.md version *\|/{av=1} hs && /\| *Session type *\|/{st=1} hs && /\| *Dispatch mode *\|/{dm=1} hs && /\| *Read profile *\|/{rp=1} /^## /{hs=0} END{
  if (ag) print "OK: Agent row in handshake table";
  else print "FAIL: Agent row not in handshake table";
  if (ro) print "OK: Role row in handshake table";
  else print "FAIL: Role row not in handshake table";
  if (mo) print "OK: Model row in handshake table";
  else print "FAIL: Model row not in handshake table";
  if (av) print "OK: AGENTS.md version row in handshake table";
  else print "FAIL: AGENTS.md version row not in handshake table";
  if (st) print "OK: Session type row in handshake table";
  else print "FAIL: Session type row not in handshake table";
  if (dm) print "OK: Dispatch mode row in handshake table";
  else print "FAIL: Dispatch mode row not in handshake table";
  if (rp) print "OK: Read profile row in handshake table";
  else print "FAIL: Read profile row not in handshake table"
}' output.txt

# Session context receipt section must exist
awk '/^## Session context receipt/{found=1} END{exit !found}' output.txt \
  && echo "OK: Session context receipt section present" \
  || echo "FAIL: Session context receipt section absent"

# DECISION: must NOT be the first line
head -1 output.txt | grep -qv "^DECISION:" \
  && echo "OK: DECISION not first line (correct for parent)" \
  || echo "FAIL: DECISION is first line (unexpected for parent)"
```

Expected: zero `FAIL:` lines.

---

## Scenario B — Dispatched non-exact-output subagent (Architect)

**Context**: Architect dispatched with a planning task.

**Expected shape**:

1. Role-specific body appears first.
2. `## Subagent session handshake` appears AFTER the role body (encouraged for non-exact-output roles).
3. `## Subagent context receipt` appears AFTER `## Subagent session handshake` (encouraged for non-exact-output roles).
4. `subagent_compliance:` YAML block appears last.

**Pass criteria**:

```bash
# Role body must appear before any trailing sections
awk 'NF > 0 && !first_nonblank { first_nonblank = NR }
  /^## Subagent session handshake/ { if (!first_opt) first_opt = NR }
  /^## Subagent context receipt/ { if (!first_opt) first_opt = NR }
  /^subagent_compliance:/ { if (!first_opt) first_opt = NR }
  END {
    if (first_nonblank > 0 && (first_opt == 0 || first_nonblank < first_opt))
      print "OK: role body content precedes trailing sections";
    else
      print "FAIL: no role body content before trailing sections"
  }' output.txt

grep -q "^## Subagent session handshake" output.txt \
  && echo "OK: Subagent session handshake section present" \
  || echo "NOTE: Subagent session handshake section absent (optional for non-exact-output roles)"

grep -q "^## Subagent context receipt" output.txt \
  && echo "OK: Subagent context receipt section present" \
  || echo "NOTE: Subagent context receipt section absent (optional for non-exact-output roles)"

awk 'NF > 0 && !first_nonblank { first_nonblank = NR }
  /^## Subagent session handshake/ { h = NR }
  END {
    if (h == 0)
      print "OK: Subagent session handshake absent (optional for non-exact-output roles)";
    else if (h != first_nonblank)
      print "OK: Subagent session handshake is not first non-blank content";
    else
      print "FAIL: Subagent session handshake is first content (positional violation)"
  }' output.txt

awk '/^## Subagent session handshake/{h=NR} /^## Subagent context receipt/{r=NR} END{
  if (h == 0 && r == 0) print "OK: both optional sections absent (valid for non-exact-output roles)";
  else if (h > 0 && r == 0) print "OK: receipt absent (optional even when handshake is present)";
  else if (h == 0 && r > 0) print "OK: receipt present without handshake (both are optional)";
  else if (h > 0 && r > h) print "OK: receipt after handshake";
  else print "FAIL: receipt appears before handshake"
}' output.txt

# subagent_compliance must be the last top-level block
awk '/^## /{last_h=NR} /^subagent_compliance:/{sc=NR} sc && NR>sc && /^[^[:space:]]/{after_sc=1} END{
  if (sc > 0 && sc > last_h && !after_sc) print "OK: subagent_compliance is last top-level block";
  else if (sc == 0) print "FAIL: subagent_compliance block missing";
  else print "FAIL: non-indented content or section heading follows subagent_compliance block"
}' output.txt
```

Expected: zero `FAIL:` lines.

---

## Scenario C — Dispatched Judge (plan-gate, exact-output)

**Dispatch**: `mode: plan-gate`

**Input payload**:

```text
## Implementation Plan — Issue #999

### Outcome
Trivial smoke-only plan. Judge receives explicit mode: plan-gate.

### Files to change
- .agents/judge.md — one-line edit
```

**Expected shape**:

1. `DECISION:` is the LITERAL FIRST LINE of the response.
2. `## Subagent session handshake` appears AFTER the role body.
3. `## Subagent context receipt` appears AFTER `## Subagent session handshake`.
4. `subagent_compliance:` YAML block appears last.
5. `Session handshake v<N>` does NOT appear as the first line.

**Pass criteria**:

```bash
# Line 1 must start with "DECISION:"
head -1 output.txt | grep -q "^DECISION:" \
  && echo "OK: DECISION is first line" \
  || echo "FAIL: DECISION is not first line"

# Session handshake token must NOT be first line
head -1 output.txt | grep -qv "^Session handshake v" \
  && echo "OK: handshake not first line (correct for exact-output subagent)" \
  || echo "FAIL: handshake is first line (positional violation for Judge)"

# Subagent session handshake must appear after DECISION content
awk '/^DECISION:/{d=NR} /^## Subagent session handshake/{h=NR} END{
  if (d > 0 && h > d) print "OK: Subagent session handshake after DECISION block";
  else print "FAIL: Subagent session handshake not after DECISION block"
}' output.txt

# Subagent context receipt must appear after Subagent session handshake
awk '/^## Subagent session handshake/{h=NR} /^## Subagent context receipt/{r=NR} END{
  if (h > 0 && r > h) print "OK: receipt after handshake";
  else print "FAIL: receipt not after handshake (or one section missing)"
}' output.txt

# subagent_compliance must be the last top-level block
awk '/^## /{last_h=NR} /^subagent_compliance:/{sc=NR} sc && NR>sc && /^[^[:space:]]/{after_sc=1} END{
  if (sc > 0 && sc > last_h && !after_sc) print "OK: subagent_compliance is last top-level block";
  else if (sc == 0) print "FAIL: subagent_compliance block missing";
  else print "FAIL: non-indented content or section heading follows subagent_compliance block"
}' output.txt

# Dispatch mode plan-gate must appear inside subagent handshake section
awk '/^## Subagent session handshake/{in_s=1} /^## Subagent context receipt/{in_s=0} in_s && /\| *Dispatch mode *\| *plan-gate *\|/{found=1} END{
  if (found) print "OK: Dispatch mode plan-gate in subagent handshake";
  else print "FAIL: Dispatch mode plan-gate not found in subagent handshake"
}' output.txt
```

Expected: zero `FAIL:` lines.

---

## Scenario D — Dispatched Critic (plan-gate, exact-output)

**Dispatch**: `mode: plan-gate`

**Input payload**:

```text
## Implementation Plan — Issue #999

### Outcome
Trivial smoke-only plan. Critic receives explicit mode: plan-gate.

### Files to change
- .agents/critic.md — one-line edit
```

**Expected shape**:

1. `CRITIC DECISION:` is the LITERAL FIRST LINE of the response.
2. `## Subagent session handshake` appears AFTER the role body.
3. `## Subagent context receipt` appears AFTER `## Subagent session handshake`.
4. `subagent_compliance:` YAML block appears last.
5. `Session handshake v<N>` does NOT appear as the first line.

**Pass criteria**:

```bash
# Line 1 must start with "CRITIC DECISION:"
head -1 output.txt | grep -q "^CRITIC DECISION:" \
  && echo "OK: CRITIC DECISION is first line" \
  || echo "FAIL: CRITIC DECISION is not first line"

# Session handshake token must NOT be first line
head -1 output.txt | grep -qv "^Session handshake v" \
  && echo "OK: handshake not first line (correct for exact-output subagent)" \
  || echo "FAIL: handshake is first line (positional violation for Critic)"

# Subagent session handshake must appear after CRITIC DECISION content
awk '/^CRITIC DECISION:/{d=NR} /^## Subagent session handshake/{h=NR} END{
  if (d > 0 && h > d) print "OK: Subagent session handshake after CRITIC DECISION block";
  else print "FAIL: Subagent session handshake not after CRITIC DECISION block"
}' output.txt

# Subagent context receipt must appear after Subagent session handshake
awk '/^## Subagent session handshake/{h=NR} /^## Subagent context receipt/{r=NR} END{
  if (h > 0 && r > h) print "OK: receipt after handshake";
  else print "FAIL: receipt not after handshake (or one section missing)"
}' output.txt

# subagent_compliance must be the last top-level block
awk '/^## /{last_h=NR} /^subagent_compliance:/{sc=NR} sc && NR>sc && /^[^[:space:]]/{after_sc=1} END{
  if (sc > 0 && sc > last_h && !after_sc) print "OK: subagent_compliance is last top-level block";
  else if (sc == 0) print "FAIL: subagent_compliance block missing";
  else print "FAIL: non-indented content or section heading follows subagent_compliance block"
}' output.txt

# Dispatch mode plan-gate must appear inside subagent handshake section
awk '/^## Subagent session handshake/{in_s=1} /^## Subagent context receipt/{in_s=0} in_s && /\| *Dispatch mode *\| *plan-gate *\|/{found=1} END{
  if (found) print "OK: Dispatch mode plan-gate in subagent handshake";
  else print "FAIL: Dispatch mode plan-gate not found in subagent handshake"
}' output.txt
```

Expected: zero `FAIL:` lines.
