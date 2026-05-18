#!/usr/bin/env bash
# scripts/checks/156-labels-declaration.sh — wires the labels-declaration bats
# fixture (scripts/tests/check-labels.bats) into test.sh discovery. The bats
# file verifies that pipeline labels — including `agent-suggested` introduced
# by ADR-027 (issue #337) — are declared in scripts/setup/40-ensure-labels.sh
# with the expected color and description. Without this wiring, the bats
# tests would be silently skipped (same class of bug as PR #312 ISS-24 and
# PR #314 ISS-01).
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions.sh} and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

echo "Running labels-declaration contract tests..."
run_bats_check scripts/tests/check-labels.bats
