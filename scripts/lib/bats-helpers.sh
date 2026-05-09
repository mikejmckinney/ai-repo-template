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
# centralises the dependency check (warn-with-skip when bats is absent
# instead of hard-failing with `command not found`) and the
# success/failure pattern that was duplicated across 7 modules.

# run_bats_check <bats_path> [<human_label>]
# Sets PASS/FAIL/WARN via pass()/fail()/warn() from assertions.sh.
# Behaviour:
#   - empty path argument → fail (caller bug; loud failure)
#   - bats not installed  → warn-skip with install hint (matches the
#                           project convention for optional CI deps
#                           like check-jsonschema; bash test.sh stays
#                           usable on bare-metal local clones)
#   - bats file missing   → fail
#   - bats file exists    → run with --tap; pass with ok-line count,
#                           or fail and print captured output.
run_bats_check() {
  local bats_path="${1:-}"
  local label="${2:-${bats_path:-<unset>}}"

  if [[ -z "$bats_path" ]]; then
    fail "run_bats_check called without a path argument (caller bug)"
    return
  fi

  if ! command -v bats >/dev/null 2>&1; then
    warn "$label skipped — bats not installed (install: apt-get install bats OR brew install bats-core)"
    return
  fi

  if [[ ! -f "$bats_path" ]]; then
    fail "$label missing"
    return
  fi

  local log
  log=$(mktemp "${TMPDIR:-/tmp}/bats-check.XXXXXX")
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
