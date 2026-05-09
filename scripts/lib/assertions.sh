#!/usr/bin/env bash
# scripts/lib/assertions.sh — shared PASS/FAIL/WARN counters and
# pass()/fail()/warn() helpers used by verification scripts.
#
# Source AFTER scripts/lib/logging.sh (this file relies on $GREEN, $RED,
# $YELLOW, $NC being defined):
#
#   # shellcheck source=scripts/lib/logging.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/logging.sh"
#   # shellcheck source=scripts/lib/assertions.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/assertions.sh"
#
# Issue #255 Phase 4a — extracted from test.sh and verify-env.sh.
# Behavior-preserving.

# Counters always start at 0 on each source. Matches the pre-extraction
# behavior of test.sh and verify-env.sh, which both initialized the
# counters unconditionally. (Using `: "${VAR:=0}"` would let inherited
# environment variables silently change the verified-pass tally — a
# regression from the previous hard zero-init.)
PASS=0
FAIL=0
WARN=0

pass() {
  printf '%b✓%b %s\n' "$GREEN" "$NC" "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '%b✗%b %s\n' "$RED" "$NC" "$1"
  FAIL=$((FAIL + 1))
}

warn() {
  printf '%b⚠%b %s\n' "$YELLOW" "$NC" "$1"
  WARN=$((WARN + 1))
}
