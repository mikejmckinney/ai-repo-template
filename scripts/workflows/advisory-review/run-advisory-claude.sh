#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export CLAUDE_REVIEW_SCHEMA="${CLAUDE_REVIEW_SCHEMA:-${ADVISORY_OUTPUT_SCHEMA:-$repo_root/.github/schemas/advisory-review.schema.json}}"
export CLAUDE_REVIEW_SESSION_ID="${CLAUDE_REVIEW_SESSION_ID:-${CLAUDE_ADVISORY_SESSION_ID:-}}"
export CLAUDE_REVIEW_SESSION_ID_FILE="${CLAUDE_REVIEW_SESSION_ID_FILE:-${CLAUDE_ADVISORY_SESSION_ID_FILE:-}}"

exec bash "$repo_root/scripts/workflows/lib/run-claude-review.sh" "$@"
