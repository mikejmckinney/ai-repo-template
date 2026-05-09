#!/bin/bash
# Template verification entry point (issue #255 Phase 4d).
#
# Thin orchestrator: sources the helper libs, then sources every numbered
# check module under scripts/checks/ in lexical order, then prints the
# summary.
#
# Each module is a behavior-preserving extraction from the pre-Phase-4d
# monolith. Modules expect:
#   - CWD == repo root (set below before sourcing).
#   - $PASS / $FAIL / $WARN counters and pass() / fail() / warn() helpers
#     from scripts/lib/assertions.sh.
#   - $RED / $GREEN / $YELLOW / $NC color vars from scripts/lib/logging.sh.
#
# Usage:
#   ./test.sh                  # run every check
#   bash test.sh               # equivalent
#
# Exit codes:
#   0  every check passed (or warnings only)
#   1  at least one check failed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/scripts/lib/logging.sh"
# shellcheck source=scripts/lib/assertions.sh
source "$SCRIPT_DIR/scripts/lib/assertions.sh"
# shellcheck source=scripts/lib/bats-helpers.sh
source "$SCRIPT_DIR/scripts/lib/bats-helpers.sh"

echo "========================================"
echo "Template Repository Verification"
echo "========================================"
echo ""

CHECKS_DIR="$SCRIPT_DIR/scripts/checks"
if [[ ! -d "$CHECKS_DIR" ]]; then
  echo -e "${RED}FATAL: scripts/checks/ directory missing${NC}" >&2
  exit 1
fi

# Source every check module in lexical order. Each module expects CWD ==
# repo root (set above) and the helper sourcings above. nullglob protects
# against the empty-modules case (which is itself a hard error, not a
# silent zero-checks pass).
#
# Modules use a 3-digit zero-padded numeric prefix (010-, 015-, ..., 100-,
# 150-) so the bash glob's lexical sort matches the author's intended
# numeric order. (Mixed-width prefixes would sort '100' before '15'.)
shopt -s nullglob
glob_pattern='[0-9][0-9][0-9]-*.sh'
# Glob via the unquoted variable — we want shell expansion. SC2206 here
# is intentional: the directory is repo-controlled (scripts/checks/) so
# there's no untrusted-input risk, and nullglob prevents the literal
# pattern from leaking through if no files match.
# shellcheck disable=SC2206
modules=("$CHECKS_DIR"/$glob_pattern)
shopt -u nullglob
if [[ ${#modules[@]} -eq 0 ]]; then
  echo -e "${RED}FATAL: no check modules found in scripts/checks/${NC}" >&2
  exit 1
fi

# Phase-prefix continuity check. The orchestrator does not enforce a
# specific numbering scheme, but it does require that every module file
# has a numeric prefix followed by '-' so the lexical sort matches the
# author's intent (e.g., 10-foo.sh, 15-bar.sh). A module without that
# prefix would be silently skipped by the glob above and is a structural
# bug worth catching here.
for m in "$CHECKS_DIR"/*.sh; do
  base=$(basename "$m")
  if [[ ! "$base" =~ ^[0-9]{3}- ]]; then
    echo -e "${RED}FATAL: check module '$base' lacks a 3-digit '<NNN>-' prefix${NC}" >&2
    exit 1
  fi
done

for module in "${modules[@]}"; do
  # shellcheck source=/dev/null
  source "$module"
done

echo ""

# --- Summary ---
echo "========================================"
echo "Summary"
echo "========================================"
echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC} $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Template verification FAILED${NC}"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo -e "${YELLOW}Template verification PASSED with warnings${NC}"
  exit 0
else
  echo -e "${GREEN}Template verification PASSED${NC}"
  exit 0
fi
