#!/usr/bin/env bash
set -euo pipefail

branch="${1:-}"
head_sha="${2:-}"
repository="${GITHUB_REPOSITORY:-}"

if [[ -z "$branch" || -z "$head_sha" || -z "$repository" ]]; then
  echo "Usage: finalize-skill-refresh.sh <branch> <head-sha>" >&2
  exit 2
fi

pulls="$(gh pr list \
  --repo "$repository" \
  --head "$branch" \
  --base main \
  --state open \
  --limit 2 \
  --json number,isDraft,headRefOid)"

if [[ "$(jq 'length' <<<"$pulls")" -ne 1 ]]; then
  echo "Expected one open aggregate pull request for $branch; leaving readiness unchanged" >&2
  exit 0
fi

pr_number="$(jq -r '.[0].number' <<<"$pulls")"
if [[ "$(jq -r '.[0].isDraft' <<<"$pulls")" != "true" ]] \
  || [[ "$(jq -r '.[0].headRefOid' <<<"$pulls")" != "$head_sha" ]]; then
  echo "Aggregate pull request is already ready or no longer has head $head_sha" >&2
  exit 0
fi

latest_exact_run() {
  local workflow="$1"
  gh run list \
    --repo "$repository" \
    --workflow "$workflow" \
    --branch "$branch" \
    --event workflow_dispatch \
    --limit 100 \
    --json headSha,status,conclusion,createdAt,url \
    | jq -c --arg head "$head_sha" \
      '[.[] | select(.headSha == $head)] | sort_by(.createdAt) | last // {}'
}

ci_run="$(latest_exact_run ci-tests.yml)"
lint_run="$(latest_exact_run lint-and-format.yml)"

if [[ "$(jq -r '.status // "missing"' <<<"$ci_run")" != "completed" ]] \
  || [[ "$(jq -r '.status // "missing"' <<<"$lint_run")" != "completed" ]]; then
  echo "Exact-head CI and lint have not both completed for $head_sha" >&2
  exit 0
fi

current="$(gh pr view "$pr_number" \
  --repo "$repository" \
  --json isDraft,headRefOid)"
if [[ "$(jq -r '.isDraft' <<<"$current")" != "true" ]] \
  || [[ "$(jq -r '.headRefOid' <<<"$current")" != "$head_sha" ]]; then
  echo "Aggregate pull request changed while checks completed; leaving readiness unchanged" >&2
  exit 0
fi

ci_conclusion="$(jq -r '.conclusion // "missing"' <<<"$ci_run")"
lint_conclusion="$(jq -r '.conclusion // "missing"' <<<"$lint_run")"
if [[ "$ci_conclusion" == "success" && "$lint_conclusion" == "success" ]]; then
  gh pr ready "$pr_number" --repo "$repository"
  exit 0
fi

marker="<!-- skill-refresh-finalizer:v1 head:$head_sha -->"
comments="$(gh api --paginate "repos/$repository/issues/$pr_number/comments" --jq '.[].body')"
if ! grep -Fq "$marker" <<<"$comments"; then
  ci_url="$(jq -r '.url // "unavailable"' <<<"$ci_run")"
  lint_url="$(jq -r '.url // "unavailable"' <<<"$lint_run")"
  gh pr comment "$pr_number" \
    --repo "$repository" \
    --body "$marker
Exact-head validation failed for \`$head_sha\`; this pull request remains draft.

- CI: $ci_conclusion ($ci_url)
- Lint: $lint_conclusion ($lint_url)"
fi
