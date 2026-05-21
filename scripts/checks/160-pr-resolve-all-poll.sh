#!/usr/bin/env bash
# scripts/checks/160-pr-resolve-all-poll.sh — pr-resolve-all poll helper tests.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh.

echo "Running pr-resolve-all poll helper tests..."
run_bats_check scripts/tests/pr-resolve-all-poll.bats

echo ""
