#!/usr/bin/env bash
# scripts/checks/158-compliance-contracts.sh — wires the compliance-contracts
# bats fixture (scripts/tests/compliance-contracts.bats) into test.sh
# discovery. The bats file pins the ADR-026 compliance-contract schema
# behaviour plus the ADR-029 regression case
# (`_case_gate_exemption_reason_rejected`) that ensures the removed
# `exemption_reason` key continues to be rejected by `_reject_unknown_keys`.
#
# Without this wiring the bats tests are silently skipped (same class of
# bug as PR #312 ISS-24 and PR #314 ISS-01); the round-2 fixture bug on
# PR #351 was caught only because Critic flagged it and bats was run
# manually.
#
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions.sh} and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

echo "Running compliance-contracts tests (ADR-026 + ADR-029)..."
run_bats_check scripts/tests/compliance-contracts.bats
