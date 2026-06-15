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
comments="$(gh issue view "$issue_num" -R "$REPO" --json comments --jq '.comments[] | select(.body | contains("'"$marker_prefix"'")) | .body' | tail -1)"
[[ -n "$comments" ]] || {
  echo "::error::No JSON snapshot comment on issue #${issue_num} for ${RUN_WEEK}" >&2
  exit 1
}

python3 - "$comments" "$OUT_JSON" <<'PY'
import re
import sys
from pathlib import Path

body, out = sys.argv[1], Path(sys.argv[2])
m = re.search(r"```json\s*\n(.*?)```", body, re.DOTALL)
if not m:
    raise SystemExit("JSON fence not found in snapshot comment")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(m.group(1).strip() + "\n", encoding="utf-8")
PY

echo "Restored weekly-review.json from issue #${issue_num} (${RUN_WEEK})"
