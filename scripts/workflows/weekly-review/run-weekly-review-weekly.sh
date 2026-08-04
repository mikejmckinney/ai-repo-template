#!/usr/bin/env bash
# Weekly full-repo review: LLM scan, umbrella issue, artifacts.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
RUN_WEEK="${RUN_WEEK:-$(bash "$SCRIPT_DIR/resolve-run-week.sh")}"
ARTIFACT_ROOT="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/weekly-review/week-${RUN_WEEK}"
mkdir -p "$ARTIFACT_ROOT"

export RUN_DATE RUN_WEEK
bash "$SCRIPT_DIR/run-weekly-review-scan.sh" "$ARTIFACT_ROOT/review.json"

WEEKLY_JSON="$ARTIFACT_ROOT/weekly-review.json"
python3 "$SCRIPT_DIR/build-weekly-review-batch.py" "$RUN_WEEK" "$RUN_DATE" "$ARTIFACT_ROOT/review.json" >"$WEEKLY_JSON"
python3 "$SCRIPT_DIR/validate-weekly-review-batch.py" "$WEEKLY_JSON"

bash "$SCRIPT_DIR/create-umbrella-issue.sh" "$WEEKLY_JSON"

FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-weekly-findings.py" "$WEEKLY_JSON")"
echo "$FINDINGS_COUNT" >"$ARTIFACT_ROOT/findings-count.txt"
echo "Weekly review complete for ${RUN_WEEK} (${FINDINGS_COUNT} findings)"
