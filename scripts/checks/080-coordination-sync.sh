#!/usr/bin/env bash
# scripts/checks/080-coordination-sync.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Coordination sync awk pipeline unit tests (issue #115) ---
# Includes a live-format assertion against .context/state/coordination.md
# so that PRs which restructure the lock template trip CI at the change
# rather than turning the workflow into a silent no-op.
echo "Running coordination sync parser unit tests..."
if [[ -f scripts/tests/coordination-sync.bats ]]; then
  CS_LOG=$(mktemp)
  if bats --tap scripts/tests/coordination-sync.bats >"$CS_LOG" 2>&1; then
    cs_passed=$(grep -c '^ok ' "$CS_LOG" || true)
    pass "scripts/tests/coordination-sync.bats ($cs_passed tests passed)"
  else
    fail "scripts/tests/coordination-sync.bats failed (see log below)"
    cat "$CS_LOG"
  fi
  rm -f "$CS_LOG"
else
  fail "scripts/tests/coordination-sync.bats missing"
fi

echo ""
