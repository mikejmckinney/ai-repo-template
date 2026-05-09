#!/usr/bin/env bash
# scripts/checks/080-coordination-sync.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

# --- Coordination sync awk pipeline unit tests (issue #115) ---
# Includes a live-format assertion against .context/state/coordination.md
# so that PRs which restructure the lock template trip CI at the change
# rather than turning the workflow into a silent no-op.
echo "Running coordination sync parser unit tests..."
run_bats_check scripts/tests/coordination-sync.bats

echo ""
