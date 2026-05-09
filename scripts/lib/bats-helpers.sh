#!/usr/bin/env bash
# scripts/lib/bats-helpers.sh — shared helper for bats-driven check modules.
#
# Source AFTER scripts/lib/{logging,assertions}.sh:
#
#   # shellcheck source=scripts/lib/bats-helpers.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/bats-helpers.sh"
#
# Issue #280 — added when the legacy scripts/test-*.sh delegate layer
# was removed, so check modules now invoke bats directly. The helper
# centralises the dependency check (skip with a fail line instead of
# hard-exiting with `command not found`) and the success/failure
# pattern that was duplicated across 7 modules.

# run_bats_check <bats_path> [<human_label>]
# Sets PASS/FAIL via the pass()/fail() helpers from assertions.sh.
# Behaviour:
#   - bats not installed → fail with install hint
#   - bats file missing → fail
#   - bats file exists  → run with --tap; pass with ok-line count, or
#                         fail and print captured output.
run_bats_check() {
  local bats_path="$1"
  local label="${2:-$bats_path}"

  if ! command -v bats >/dev/null 2>&1; then
    fail "$label skipped — bats not installed (install: apt-get install bats OR brew install bats-core)"
    return
  fi

  if [[ ! -f "$bats_path" ]]; then
    fail "$label missing"
    return
  fi

  local log
  log=$(mktemp)
  if bats --tap "$bats_path" >"$log" 2>&1; then
    local n
    n=$(grep -c '^ok ' "$log" || true)
    pass "$label ($n tests passed)"
  else
    fail "$label failed (see log below)"
    cat "$log"
  fi
  rm -f "$log"
}
