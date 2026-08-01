#!/usr/bin/env bash
# Restore weekly-review.json from umbrella issue snapshot comment.
# Usage: fetch-weekly-review-json-from-issue.sh <run-week> <out-json>
set -euo pipefail

RUN_WEEK="${1:-}"
OUT_JSON="${2:-}"
usage() {
  echo "Usage: fetch-weekly-review-json-from-issue.sh <run-week> <out-json>" >&2
  exit 2
}
[[ -n "$RUN_WEEK" && -n "$OUT_JSON" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
issue_num="$(bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_WEEK")" || {
  echo "::error::No umbrella issue for ${RUN_WEEK}" >&2
  exit 1
}

marker_prefix="<!-- weekly-review:json:${RUN_WEEK}"
comments_file="$(mktemp)"
trap 'rm -f "$comments_file"' EXIT
if ! gh api --paginate --slurp \
  "repos/${REPO}/issues/${issue_num}/comments?per_page=100" >"$comments_file"; then
  echo "::error::Unable to read comments on issue #${issue_num}" >&2
  exit 1
fi

python3 - "$comments_file" "$marker_prefix" "$OUT_JSON" "$issue_num" "$RUN_WEEK" <<'PY'
import json
import re
import sys
from pathlib import Path

comments_file = Path(sys.argv[1])
marker, out = sys.argv[2], Path(sys.argv[3])
issue_num, run_week = sys.argv[4], sys.argv[5]
pages = json.loads(comments_file.read_text(encoding="utf-8"))
comments = [comment for page in pages for comment in page]
matching = [comment for comment in comments if marker in comment.get("body", "")]
if not matching:
    raise SystemExit(
        f"::error::No JSON snapshot comment on issue #{issue_num} for {run_week}"
    )
body = max(matching, key=lambda comment: comment.get("id", 0))["body"]
m = re.search(r"```json\s*\n(.*?)```", body, re.DOTALL)
if not m:
    raise SystemExit("JSON fence not found in snapshot comment")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(m.group(1).strip() + "\n", encoding="utf-8")
PY

echo "Restored weekly-review.json from issue #${issue_num} (${RUN_WEEK})"
