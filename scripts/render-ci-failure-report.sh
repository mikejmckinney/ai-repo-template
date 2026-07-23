#!/usr/bin/env bash

set -euo pipefail

OUTPUT_FILE="${1:-}"
BATS_OUTCOME="${2:-}"
TEST_OUTCOME="${3:-}"
BATS_LOG="${4:-}"
TEST_LOG="${5:-}"
[[ -n "$OUTPUT_FILE" && -n "$BATS_OUTCOME" && -n "$TEST_OUTCOME" ]] || {
  echo "Usage: render-ci-failure-report.sh <output> <bats-outcome> <test-outcome> <bats-log> <test-log>" >&2
  exit 2
}

append_failure() {
  local heading="$1" outcome="$2" log_file="$3"
  [[ "$outcome" == failure ]] || return 0
  {
    echo ""
    echo "### ${heading}"
    echo '```text'
    if [[ -f "$log_file" ]]; then
      tail -c 20000 "$log_file" | tail -n 100
    else
      echo "No output captured"
    fi
    echo '```'
  } >>"$OUTPUT_FILE"
}

{
  echo "## CI Failure Report"
  echo ""
  echo "**Workflow:** ${CI_WORKFLOW:-unknown}"
  echo "**Run:** [#${CI_RUN_NUMBER:-unknown}](${CI_RUN_URL:-#})"
  echo "**Branch:** ${CI_BRANCH:-unknown}"
  echo "**Commit:** ${CI_COMMIT:-unknown}"
  echo "**Retry Count:** ${CI_RETRY_COUNT:-0}/${CI_MAX_RETRIES:-0}"
} >"$OUTPUT_FILE"

append_failure "Bats Failure Output" "$BATS_OUTCOME" "$BATS_LOG"
append_failure "Repository Check Failure Output" "$TEST_OUTCOME" "$TEST_LOG"
