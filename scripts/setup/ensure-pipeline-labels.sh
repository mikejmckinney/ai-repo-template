#!/usr/bin/env bash
# ensure-pipeline-labels.sh — Idempotently create pipeline labels on a target repo.
#
# Usage:
#   ./scripts/setup/ensure-pipeline-labels.sh [owner/repo]
#   GH_REPO=owner/repo ./scripts/setup/ensure-pipeline-labels.sh
#
# Wraps the label-creation block in 40-ensure-labels.sh. Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/../lib/logging.sh"

TARGET="${1:-${GH_REPO:-${GITHUB_REPOSITORY:-}}}"
if [[ -z "$TARGET" ]]; then
  log_error "Usage: ensure-pipeline-labels.sh <owner/repo> (or set GH_REPO)"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  log_error "gh must be authenticated to ensure pipeline labels on ${TARGET}"
  exit 1
fi

FULL_REPO="$TARGET"
export GH_REPO="$TARGET"
_gh_auth_ok="true"
_pipeline_setup_skip_reason=""
# 40-ensure-labels.sh expects SCRIPT_DIR=scripts/ (parent of setup/), not scripts/setup/.
SCRIPT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/setup/40-ensure-labels.sh
source "$SCRIPT_DIR/setup/40-ensure-labels.sh"
