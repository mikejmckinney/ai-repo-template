#!/usr/bin/env bash
# scripts/checks/075-parallelism-report-parser.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

# --- Parallelism report parser unit tests (issue #49 / ADR-009) ---
# Includes a live-format assertion against agent_ownership.md so that
# format-changing PRs to the ownership table fail CI at the change PR
# rather than at the next overlap report.
echo "Running parallelism report parser unit tests..."
run_bats_check scripts/tests/parallelism-report-parser.bats

echo ""
