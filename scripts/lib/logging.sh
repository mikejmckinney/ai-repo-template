#!/usr/bin/env bash
# scripts/lib/logging.sh — shared color codes and log_* helpers.
#
# Source from any script that wants the canonical [INFO]/[WARN]/[ERROR]/==>
# logging style. Use the repo-root-relative path so the example works for
# both root-level scripts (test.sh) and scripts under scripts/:
#
#   # From a script in scripts/:
#   # shellcheck source=scripts/lib/logging.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/logging.sh"
#
#   # From a root-level script (test.sh):
#   # shellcheck source=scripts/lib/logging.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib/logging.sh"
#
# Issue #255 Phase 4a — extracted from setup.sh, db-reset.sh,
# sandbox-bootstrap.sh. One deliberate semantic change: log_error now
# always writes to stderr (matching sandbox-bootstrap.sh's pre-extraction
# behavior and Unix convention). The pre-extraction setup.sh and
# db-reset.sh wrote log_error to stdout; that was a pre-existing
# inconsistency, not contract.

# Colors. Unconditional — matches the existing top-level scripts. Scripts
# that need tty-aware colors gate them locally instead
# of using these defaults.
# shellcheck disable=SC2034 # exported for sourcing scripts
RED='\033[0;31m'
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
BLUE='\033[0;34m'
# shellcheck disable=SC2034
NC='\033[0m'

log_info() { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"; }
log_warn() { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2; }
log_step() { printf '\n%b==>%b %s\n' "$GREEN" "$NC" "$1"; }
