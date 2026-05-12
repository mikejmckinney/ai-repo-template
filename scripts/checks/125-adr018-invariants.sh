#!/usr/bin/env bash
# scripts/checks/125-adr018-invariants.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- ADR-018 invariants (issue #237 / legacy multi-task _active.md schema) ---
echo "Checking ADR-018 components (issue #237 / legacy multi-task _active.md)..."

ADR018_PATH="docs/decisions/adr-018-multi-task-active-md-schema.md"
if [[ -f "$ADR018_PATH" ]] \
  && grep -qE '^Accepted \(superseded in part by ADR-025\)$' "$ADR018_PATH" 2>/dev/null; then
  pass "ADR-018 exists with Status: Accepted (superseded in part by ADR-025)"
else
  fail "ADR-018 missing or Status line is not 'Accepted (superseded in part by ADR-025)' ($ADR018_PATH)"
fi

# ADR-025 supersedes the old repo-local live-state parts of ADR-009.
if grep -qiE 'superseded in part by ADR-025' docs/decisions/adr-009-parallel-multi-agent-execution.md 2>/dev/null; then
  pass "ADR-009 is marked superseded in part by ADR-025 for live state"
else
  fail "ADR-009 missing ADR-025 supersession marker"
fi

if grep -q 'ADR-018' docs/decisions/README.md 2>/dev/null; then
  pass "docs/decisions/README.md indexes ADR-018"
else
  fail "docs/decisions/README.md missing ADR-018 row"
fi

# Postmortem-003 ships in the same PR (ADR-015 feedback loop).
PM003_PATH="docs/postmortems/postmortem-003-active-md-merge-conflict.md"
if [[ -f "$PM003_PATH" ]] \
  && grep -q '^generalizes: Yes' "$PM003_PATH" 2>/dev/null \
  && grep -q '^follow_up_artifact: ADR-018' "$PM003_PATH" 2>/dev/null; then
  pass "postmortem-003 exists with generalizes:Yes + follow_up_artifact:ADR-018"
else
  fail "postmortem-003 missing or frontmatter incomplete ($PM003_PATH)"
fi

# Smoke test for parallel-merge safety.
SMOKE_PATH="scripts/tests/active-md-multitask.bats"
if [[ -f "$SMOKE_PATH" ]]; then
  pass "$SMOKE_PATH exists (ADR-018 smoke test)"
else
  fail "$SMOKE_PATH missing (ADR-018 smoke test)"
fi

# Cadence rule references ADR-025 and the agent-state comment template.
if grep -q 'ADR-025' .context/rules/process_session_state.md 2>/dev/null \
  && grep -q 'agent-state:v1' .context/rules/process_session_state.md 2>/dev/null; then
  pass "process_session_state.md references ADR-025 agent-state live state"
else
  fail "process_session_state.md missing ADR-025 / agent-state:v1 live-state guidance"
fi

# .context/state/README.md documents ADR-025 legacy compatibility status.
if grep -q 'ADR-025' .context/state/README.md 2>/dev/null \
  && grep -q 'agent_state_comment_template.md' .context/state/README.md 2>/dev/null; then
  pass ".context/state/README.md documents ADR-025 state compatibility"
else
  fail ".context/state/README.md missing ADR-025 state compatibility guidance"
fi

echo ""
