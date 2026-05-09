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
shopt -s nullglob
_setup_modules=("$SCRIPT_DIR"/setup/[0-9][0-9]-*.sh)
shopt -u nullglob
if [[ ${#_setup_modules[@]} -eq 0 ]]; then
  printf '\033[0;31m[ERROR]\033[0m No setup modules found in %s/setup/. Expected files matching [0-9][0-9]-*.sh — likely a partial checkout or packaging error.\n' "$SCRIPT_DIR" >&2
  exit 1
fi
for _module in "${_setup_modules[@]}"; do
  # shellcheck source=/dev/null
  source "$_module"
done
unset _module _setup_modules

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
