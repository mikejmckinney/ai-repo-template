#!/usr/bin/env bash
# Collect repo inventory for weekly full-repo review.
# Usage: collect-weekly-evidence.sh <workdir>
set -euo pipefail

WORKDIR="${1:-}"
[[ -n "$WORKDIR" && -d "$WORKDIR" ]] || {
  echo "Usage: collect-weekly-evidence.sh <workdir>" >&2
  exit 2
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

git rev-parse HEAD >"$WORKDIR/head-sha.txt"
git log --since=7.days --oneline -80 >"$WORKDIR/recent-commits.txt" 2>/dev/null || true

git ls-files >"$WORKDIR/all-files.txt"
grep -E '^(scripts/|\.github/workflows/|docs/decisions/|\.context/|test\.sh|AI_REPO_GUIDE\.md|AGENTS\.md)' \
  "$WORKDIR/all-files.txt" >"$WORKDIR/changed-files.txt" || true

{
  echo "## Repository inventory (automation-supplied)"
  echo ""
  echo "- HEAD SHA: \`$(cat "$WORKDIR/head-sha.txt")\`"
  echo "- Tracked files (subset): see changed-files.txt"
  echo ""
  echo "### Recent commits (7 days)"
  echo ""
  sed 's/^/- /' "$WORKDIR/recent-commits.txt"
  echo ""
  echo "### Workflow files"
  echo ""
  for wf in .github/workflows/*.yml; do
    [[ -f "$wf" ]] || continue
    echo "#### ${wf}"
    echo ""
    echo '```yaml'
    cat "$wf"
    echo '```'
    echo ""
  done
  echo "### Check modules"
  echo ""
  ls -1 scripts/checks/*.sh 2>/dev/null | sed 's/^/- /' || true
} >"$WORKDIR/repo-inventory.md"

wc -l "$WORKDIR/all-files.txt" | awk '{print $1}' >"$WORKDIR/file-count.txt"

echo "Collected weekly evidence ($(cat "$WORKDIR/file-count.txt") tracked files)"
