#!/usr/bin/env bash
# scripts/checks/140-pr-iteration-stats-smoke.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

# --- pr-iteration-stats.sh smoke tests (issue #229 Phase 1) ---
echo "Running pr-iteration-stats.sh smoke tests..."
run_bats_check scripts/tests/pr-iteration-stats.bats

echo ""
