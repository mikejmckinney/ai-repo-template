#!/usr/bin/env bash
# scripts/checks/088-diag-hang-snapshot.sh — added by PR #297 Round 9 (ISS-50),
# renamed from 090- in Round 11 (ISS-65) to clear the prefix collision with
# 090-auto-rebase.sh.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

# --- diag-hang-snapshot.sh smoke tests (issue #229 Phase 1.5 diff-coupling) ---
# scripts/diag-hang-snapshot.sh introduces `set -uo pipefail` and is therefore
# subject to the diff-coupling gate; the bats file exercises script existence,
# warning-clean shellcheck status, the pipefail directive, a one-sample
# smoke run, and OUTDIR honoring.
echo "Running diag-hang-snapshot smoke tests..."
run_bats_check scripts/tests/diag-hang-snapshot.bats
