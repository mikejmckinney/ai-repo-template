#!/usr/bin/env bash
# Append merge_commit_sha index markers to an umbrella issue Meta section.
# Usage: append-merge-index-markers.sh <issue-num> <daily-retro.json>
set -euo pipefail

ISSUE_NUM="${1:-}"
DAILY_JSON="${2:-}"
usage() {
  echo "Usage: append-merge-index-markers.sh <issue-num> <daily-retro.json>" >&2
  exit 2
}
[[ -n "$ISSUE_NUM" && -f "$DAILY_JSON" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

body="$(gh issue view "$ISSUE_NUM" -R "$REPO" --json body --jq .body)"
printf '%s' "$body" >"$WORKDIR/body.md"

python3 - "$DAILY_JSON" "$WORKDIR/body.md" "$WORKDIR/merged.md" <<'PY'
import json
import re
import sys
from pathlib import Path

daily = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
body = Path(sys.argv[2]).read_text(encoding="utf-8")
out = Path(sys.argv[3])

markers: list[str] = []
for row in daily.get("pr_merges") or []:
    pr = row.get("pr")
    sha = str(row.get("merge_commit_sha") or "").strip().lower()
    if not pr or not sha:
        continue
    marker = f"<!-- postmerge-retro:merge:{sha} pr:{pr} -->"
    if marker not in body:
        markers.append(marker)

if not markers:
    out.write_text(body)
    sys.exit(0)

block = "\n".join(["", "**Indexed merge commits (automation):**", *markers, ""])
if "## Meta" in body:
    head, tail = body.split("## Meta", 1)
    merged = head.rstrip() + block + "\n\n## Meta" + tail
else:
    merged = body.rstrip() + block + "\n"
out.write_text(merged)
PY

merged="$(cat "$WORKDIR/merged.md")"
if [[ "$merged" != "$body" ]]; then
  gh issue edit "$ISSUE_NUM" -R "$REPO" --body "$merged"
  echo "Appended merge index markers to issue #${ISSUE_NUM}" >&2
fi
