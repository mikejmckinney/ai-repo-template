#!/usr/bin/env bash
# Restore daily-retro.json from the latest umbrella issue snapshot comment.
# Usage: fetch-daily-retro-json-from-issue.sh <run-date> [output-path]
set -euo pipefail

RUN_DATE="${1:-}"
OUT="${2:-}"
usage() {
  echo "Usage: fetch-daily-retro-json-from-issue.sh <run-date> [output-path]" >&2
  exit 2
}
[[ -n "$RUN_DATE" ]] || usage

OUT="${OUT:-${2:-$(mktemp)}}"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUE_NUM="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_DATE" "$OUT" 2>/dev/null)" || {
  echo "::error::No umbrella issue found for ${RUN_DATE}" >&2
  exit 1
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

gh api "repos/${REPO}/issues/${ISSUE_NUM}/comments" --paginate \
  | jq -s 'if length == 0 then [] else add end' >"$WORKDIR/comments.json"

python3 - "$RUN_DATE" "$WORKDIR/comments.json" "$WORKDIR/daily-retro.json" <<'PY'
import json
import re
import sys
from pathlib import Path

run_date, comments_path, out_path = sys.argv[1:4]
prefix = f"<!-- postmerge-retro:daily-json:{run_date}"
comments = json.loads(Path(comments_path).read_text(encoding="utf-8"))

candidates: list[tuple[int, int, str]] = []
for item in comments:
    body = item.get("body") or ""
    if prefix not in body:
        continue
    header = body.splitlines()[0] if body else ""
    run_m = re.search(r"run:(\d+)", header)
    attempt_m = re.search(r"attempt:(\d+)", header)
    run_id = int(run_m.group(1)) if run_m else 0
    attempt = int(attempt_m.group(1)) if attempt_m else 0
    candidates.append((run_id, attempt, body))

if not candidates:
    print(f"No daily JSON snapshot comments for {run_date}", file=sys.stderr)
    sys.exit(1)

candidates.sort(key=lambda item: (item[0], item[1]))
body = candidates[-1][2]
match = re.search(r"```json\s*(.*?)\s*```", body, re.DOTALL)
if not match:
    print("Snapshot comment missing ```json block", file=sys.stderr)
    sys.exit(1)

Path(out_path).write_text(match.group(1).strip() + "\n", encoding="utf-8")
PY

mkdir -p "$(dirname "$OUT")"
cp "$WORKDIR/daily-retro.json" "$OUT"
python3 "$SCRIPT_DIR/validate-postmerge-retro-daily.py" "$OUT"
echo "Restored daily-retro.json for ${RUN_DATE} from issue #${ISSUE_NUM} -> ${OUT}"
