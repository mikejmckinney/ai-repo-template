#!/usr/bin/env bash
# scripts/checks/85-multi-dispatch-safety.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Multi-dispatch safety library unit tests (issue #114) ---
# Exercises the four pure-bash functions in
# scripts/multi-dispatch-safety.sh that the multi-issue dispatcher
# (.github/workflows/agent-multi-dispatch.yml) relies on for conflict
# detection. If these regress, the dispatcher would silently assign
# Copilot to overlapping issues. Hard-fail keeps regressions out of CI.
echo "Running multi-dispatch safety unit tests..."
if [[ -f scripts/test-multi-dispatch-safety.sh ]]; then
  MDS_LOG=$(mktemp)
  if bash scripts/test-multi-dispatch-safety.sh >"$MDS_LOG" 2>&1; then
    mds_passed=$(grep -c '^  ✅ ' "$MDS_LOG" || true)
    pass "scripts/test-multi-dispatch-safety.sh ($mds_passed assertions passed)"
  else
    fail "scripts/test-multi-dispatch-safety.sh failed (see log below)"
    cat "$MDS_LOG"
  fi
  rm -f "$MDS_LOG"
else
  fail "scripts/test-multi-dispatch-safety.sh missing"
fi

echo ""
