#!/usr/bin/env bash
# Replace umbrella Meta placeholder with the draft fix PR URL.
# Usage: update-umbrella-fix-link.sh <run-date> <fix-pr-url>
set -euo pipefail

usage() {
  echo "Usage: update-umbrella-fix-link.sh <run-date> <fix-pr-url>" >&2
  exit 2
}

RUN_DATE="${1:-}"
FIX_PR_URL="${2:-}"
[[ -n "$RUN_DATE" && -n "$FIX_PR_URL" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
MARKER="<!-- postmerge-retro:daily:${RUN_DATE} -->"
PENDING='(pending — fix job)'

issue_num=""
while read -r candidate; do
  [[ -z "$candidate" ]] && continue
  body="$(gh issue view "$candidate" -R "$REPO" --json body --jq .body 2>/dev/null || true)"
  if grep -Fq "$MARKER" <<<"$body" && grep -Eq "^[[:space:]]*<!-- postmerge-retro:daily:" <<<"$body"; then
    issue_num="$candidate"
    break
  fi
done < <(gh search issues "postmerge-retro:daily:${RUN_DATE} is:issue" --repo "$REPO" --json number --limit 10 --jq '.[].number' 2>/dev/null || true)
[[ -n "$issue_num" ]] || {
  echo "::warning::No umbrella issue found for ${RUN_DATE}; skipping fix-link update"
  exit 0
}

body="$(gh issue view "$issue_num" -R "$REPO" --json body --jq .body)"
grep -Fq "$MARKER" <<<"$body" || {
  echo "::error::Issue #${issue_num} missing daily marker for ${RUN_DATE}" >&2
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
