#!/usr/bin/env bash
# scripts/checks/070-phase4-fallback-parser.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

# --- Phase 4 fallback parser unit tests (issue #108 regression cover) ---
echo "Running Phase 4 fallback parser unit tests..."
run_bats_check scripts/tests/phase4-fallback-parser.bats

echo ""
