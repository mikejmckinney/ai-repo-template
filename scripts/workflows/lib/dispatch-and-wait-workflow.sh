#!/usr/bin/env bash
set -euo pipefail

workflow="${1:-}"
branch="${2:-}"
head_sha="${3:-}"
shift $(($# >= 3 ? 3 : $#))

if [[ -z "$workflow" || -z "$branch" || -z "$head_sha" ]]; then
  echo "Usage: dispatch-and-wait-workflow.sh <workflow> <branch> <head-sha> [workflow inputs...]" >&2
  exit 2
fi

before_runs="$(gh run list \
  --workflow "$workflow" \
  --branch "$branch" \
  --event workflow_dispatch \
  --limit 100 \
  --json databaseId,headSha,createdAt)"

gh workflow run "$workflow" --ref "$branch" "$@"

run_id=""
for _ in $(seq 1 30); do
  after_runs="$(gh run list \
    --workflow "$workflow" \
    --branch "$branch" \
    --event workflow_dispatch \
    --limit 100 \
    --json databaseId,headSha,createdAt)"
  run_id="$(jq -nr \
    --argjson before "$before_runs" \
    --argjson after "$after_runs" \
    --arg head "$head_sha" '
      ($before | map(.databaseId)) as $existing
      | [$after[]
          | select(.headSha == $head)
          | select(.databaseId as $id | ($existing | index($id)) == null)]
      | sort_by(.createdAt)
      | first.databaseId // empty
    ')"
  [[ -n "$run_id" ]] && break
  sleep 2
done

if [[ -z "$run_id" ]]; then
  echo "Timed out resolving newly dispatched $workflow run for $head_sha" >&2
  exit 1
fi

gh run watch "$run_id" --exit-status
