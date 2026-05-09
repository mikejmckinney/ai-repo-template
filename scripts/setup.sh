#!/bin/bash
# Description: One-command project setup
# Usage: ./scripts/setup.sh
#
# Thin orchestrator. Each phase lives in its own module under
# scripts/setup/<NN>-*.sh and is sourced in lexical order. See
# scripts/setup/README.md for the module table and how to run a single
# module in isolation.
#
# TEMPLATE_PLACEHOLDER: Customize this for your project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

echo "========================================"
echo "Project Setup"
echo "========================================"

# Source every setup module in lexical order. Modules share the parent
# shell's environment (FULL_REPO, _gh_auth_ok, _pipeline_setup_skip_reason,
# GH_REPO, etc.) so 50/60 can read state set up by 00 and 40.
#
# Expected phases. Asserting the manifest (rather than just non-emptiness)
# catches partial-checkout regressions where a single module file is
# missing — without this check the orchestrator would silently skip that
# phase and still print "Setup Complete". Keep this list in sync with
# scripts/setup/README.md.
_expected_phases=(00 10 20 30 40 50 60 70)
_setup_modules=()
shopt -s nullglob
for _module in "$SCRIPT_DIR"/setup/[0-9][0-9]-*.sh; do
  _setup_modules+=("$_module")
done
shopt -u nullglob
_red=$'\033[0;31m'
_nc=$'\033[0m'
if [[ ${#_setup_modules[@]} -eq 0 ]]; then
  printf '%b[ERROR]%b No setup modules found in %s/setup/. Expected files matching [0-9][0-9]-*.sh — likely a partial checkout or packaging error.\n' \
    "$_red" "$_nc" "$SCRIPT_DIR" >&2
  exit 1
fi
_missing=()
for _phase in "${_expected_phases[@]}"; do
  _found=""
  for _module in "${_setup_modules[@]}"; do
    case "$(basename "$_module")" in
      "${_phase}"-*.sh)
        _found="$_module"
        break
        ;;
    esac
  done
  if [[ -z "$_found" ]]; then
    _missing+=("$_phase")
  fi
done
if [[ ${#_missing[@]} -gt 0 ]]; then
  printf '%b[ERROR]%b Missing setup phase module(s): %s. Expected one %s/setup/<NN>-*.sh per phase prefix in: %s. See scripts/setup/README.md.\n' \
    "$_red" "$_nc" "${_missing[*]}" "$SCRIPT_DIR" "${_expected_phases[*]}" >&2
  exit 1
fi
unset _phase _found _missing _red _nc
for _module in "${_setup_modules[@]}"; do
  # shellcheck source=/dev/null
  source "$_module"
done
unset _module _setup_modules _expected_phases

# --- Done ---
echo ""
echo "========================================"
printf '%bSetup Complete!%b\n' "$GREEN" "$NC"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Review .env and update any placeholder values"
echo "  2. Check .context/00_INDEX.md for project context"
echo "  3. Start development!"
echo ""

# Show available scripts if package.json exists
if [[ -f "package.json" ]]; then
  echo "Available npm scripts:"
  grep -E '^\s+"[^"]+":' package.json | head -10 | sed 's/[",]//g' | sed 's/^/  /'
fi
