#!/usr/bin/env bash
# Persist umbrella issue number into weekly-review.json and sidecar.
# Usage: write-umbrella-issue-ref.sh <weekly-review.json> <issue-number>
set -euo pipefail

WEEKLY_JSON="${1:-}"
ISSUE_NUM="${2:-}"
usage() {
  echo "Usage: write-umbrella-issue-ref.sh <weekly-review.json> <issue-number>" >&2
  exit 2
}
[[ -n "$WEEKLY_JSON" && -f "$WEEKLY_JSON" && -n "$ISSUE_NUM" ]] || usage

normalize_issue_num() {
  tr -d '[:space:]' <<<"${1:-}"
}

ISSUE_NUM="$(normalize_issue_num "$ISSUE_NUM")"
[[ "$ISSUE_NUM" =~ ^[0-9]+$ ]] || {
  echo "::error::issue-number must be a positive integer: '${ISSUE_NUM}'" >&2
  exit 1
}

python3 - "$WEEKLY_JSON" "$ISSUE_NUM" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
issue_num = int(sys.argv[2])
data = json.loads(path.read_text(encoding="utf-8"))
data["umbrella_issue"] = issue_num
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

printf '%s\n' "$ISSUE_NUM" >"$(dirname "$WEEKLY_JSON")/umbrella-issue.txt"
echo "Recorded umbrella_issue=${ISSUE_NUM} in ${WEEKLY_JSON}"
