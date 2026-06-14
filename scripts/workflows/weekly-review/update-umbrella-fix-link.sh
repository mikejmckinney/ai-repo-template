#!/usr/bin/env bash
# Replace umbrella Meta placeholder with the draft fix PR URL.
# Usage: update-umbrella-fix-link.sh <run-week> <fix-pr-url> [weekly-review.json]
set -euo pipefail

usage() {
  echo "Usage: update-umbrella-fix-link.sh <run-week> <fix-pr-url> [weekly-review.json]" >&2
  exit 2
}

RUN_WEEK="${1:-}"
FIX_PR_URL="${2:-}"
WEEKLY_JSON="${3:-${WEEKLY_JSON:-}}"
[[ -n "$RUN_WEEK" && -n "$FIX_PR_URL" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="<!-- weekly-review:${RUN_WEEK} -->"
PENDING='(pending — fix job)'

issue_num=""
if issue_num="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_WEEK" "$WEEKLY_JSON" 2>/dev/null)"; then
  :
else
  issue_num=""
fi
[[ -n "$issue_num" ]] || {
  echo "::warning::No umbrella issue found for ${RUN_WEEK}; skipping fix-link update"
  exit 0
}

body="$(gh issue view "$issue_num" -R "$REPO" --json body --jq .body)"
grep -Fq "$MARKER" <<<"$body" || {
  echo "::error::Issue #${issue_num} missing weekly marker for ${RUN_WEEK}" >&2
  exit 1
}

if grep -Fq "$FIX_PR_URL" <<<"$body"; then
  echo "Umbrella issue #${issue_num} already links fix PR"
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
printf '%s' "$body" >"$WORKDIR/body.md"

updated="$(
  python3 - "$WORKDIR/body.md" "$FIX_PR_URL" "$PENDING" <<'PY'
import re
import sys
from pathlib import Path

body_path, fix_url, pending = sys.argv[1:4]
body = Path(body_path).read_text(encoding="utf-8")
link_line = f"Draft fix PR (if created): {fix_url}"
if fix_url in body:
    print(body)
    raise SystemExit(0)
if pending in body:
    body = body.replace(pending, fix_url, 1)
elif re.search(r"Draft fix PR \(if created\):\s*\S+", body):
    body = re.sub(
        r"Draft fix PR \(if created\):\s*[^\n]+",
        link_line,
        body,
        count=1,
    )
else:
    body = body.rstrip() + f"\n{link_line}\n"
print(body)
PY
)"

printf '%s' "$updated" >"$WORKDIR/body-updated.md"
gh issue edit "$issue_num" -R "$REPO" --body-file "$WORKDIR/body-updated.md"
echo "Updated umbrella issue #${issue_num} with fix PR link"
