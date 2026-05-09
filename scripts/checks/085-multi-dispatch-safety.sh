#!/usr/bin/env bash
# scripts/checks/085-multi-dispatch-safety.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

# --- Multi-dispatch safety library unit tests (issue #114) ---
# Exercises the four pure-bash functions in
# scripts/multi-dispatch-safety.sh that the multi-issue dispatcher
# (.github/workflows/agent-multi-dispatch.yml) relies on for conflict
# detection. If these regress, the dispatcher would silently assign
# Copilot to overlapping issues. Hard-fail keeps regressions out of CI.
echo "Running multi-dispatch safety unit tests..."
run_bats_check scripts/tests/multi-dispatch-safety.bats

echo ""
