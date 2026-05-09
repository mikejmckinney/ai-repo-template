#!/usr/bin/env bash
# scripts/checks/085-multi-dispatch-safety.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Multi-dispatch safety library unit tests (issue #114) ---
# Exercises the four pure-bash functions in
# scripts/multi-dispatch-safety.sh that the multi-issue dispatcher
# (.github/workflows/agent-multi-dispatch.yml) relies on for conflict
# detection. If these regress, the dispatcher would silently assign
# Copilot to overlapping issues. Hard-fail keeps regressions out of CI.
echo "Running multi-dispatch safety unit tests..."
if [[ -f scripts/tests/multi-dispatch-safety.bats ]]; then
  MDS_LOG=$(mktemp)
  if bats --tap scripts/tests/multi-dispatch-safety.bats >"$MDS_LOG" 2>&1; then
    mds_passed=$(grep -c '^ok ' "$MDS_LOG" || true)
    pass "scripts/tests/multi-dispatch-safety.bats ($mds_passed tests passed)"
  else
    fail "scripts/tests/multi-dispatch-safety.bats failed (see log below)"
    cat "$MDS_LOG"
  fi
  rm -f "$MDS_LOG"
else
  fail "scripts/tests/multi-dispatch-safety.bats missing"
fi

echo ""
