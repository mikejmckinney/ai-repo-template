#!/usr/bin/env bash
# scripts/checks/140-pr-iteration-stats-smoke.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- pr-iteration-stats.sh smoke tests (issue #229 Phase 1) ---
echo "Running pr-iteration-stats.sh smoke tests..."
if [[ -f scripts/tests/pr-iteration-stats.bats ]]; then
  PIS_LOG=$(mktemp)
  if bats --tap scripts/tests/pr-iteration-stats.bats >"$PIS_LOG" 2>&1; then
    pis_passed=$(grep -c '^ok ' "$PIS_LOG" || true)
    pass "scripts/tests/pr-iteration-stats.bats ($pis_passed tests passed)"
  else
    fail "scripts/tests/pr-iteration-stats.bats failed (see log below)"
    cat "$PIS_LOG"
  fi
  rm -f "$PIS_LOG"
else
  fail "scripts/tests/pr-iteration-stats.bats missing"
fi

echo ""
