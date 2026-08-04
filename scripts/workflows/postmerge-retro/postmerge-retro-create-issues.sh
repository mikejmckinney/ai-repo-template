#!/usr/bin/env bash
# scripts/workflows/postmerge-retro/postmerge-retro-create-issues.sh
# Idempotently create follow-up issues from retro.json.
# Usage: postmerge-retro-create-issues.sh <retro.json>
set -euo pipefail

usage() {
  echo "Usage: postmerge-retro-create-issues.sh <retro.json>" >&2
  exit 2
}

RETRO_JSON="${1:-}"
[[ -n "$RETRO_JSON" && -f "$RETRO_JSON" ]] || usage

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/validate-postmerge-retro.py" "$RETRO_JSON"

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
PR="$(jq -r .pr "$RETRO_JSON")"

marker_exists() {
  local marker="$1"
  local count
  count="$(gh search issues --repo "$REPO" "$marker" --json number --limit 1 --jq 'length' 2>/dev/null || echo 0)"
  [[ "${count:-0}" -gt 0 ]]
}

label_exists_in_repo() {
  local lb="$1"
  gh api "repos/${REPO}/labels/${lb}" >/dev/null 2>&1
}

create_issue() {
  local title="$1" body_file="$2" labels_csv="$3"
  local -a label_args=() lb
  IFS=',' read -ra labels <<<"$labels_csv"
  for lb in "${labels[@]}"; do
    lb="$(echo "$lb" | xargs)"
    [[ -z "$lb" ]] && continue
    if label_exists_in_repo "$lb"; then
      label_args+=(--label "$lb")
    else
      echo "::warning::Label '${lb}' not found in ${REPO}; creating issue without it"
    fi
  done
  gh issue create --title "$title" --body-file "$body_file" "${label_args[@]}"
  echo "Created issue: ${title}"
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  title="$(printf '%s' "$row" | jq -r .title)"
  dedupe="$(printf '%s' "$row" | jq -r .dedupe_key)"
  marker="<!-- postmerge-retro:pr=${PR}:key=${dedupe} -->"
  if marker_exists "$marker"; then
    echo "Skip (exists): ${marker}"
    continue
  fi
  labels_csv="$(printf '%s' "$row" | jq -r '(.labels // []) + ["agent-suggested"] | unique | join(",")')"
  body_file="$WORKDIR/follow-${dedupe}.md"
  {
    printf '%s\n\n' "$marker"
    printf 'Source merged PR: #%s (%s)\n\n' "$PR" "$REPO"
    printf '%s\n\n' "$(printf '%s' "$row" | jq -r .body)"
    ev="$(printf '%s' "$row" | jq -r '.evidence // [] | if length == 0 then empty else "### Evidence\n" + (map("- " + .) | join("\n")) end')"
    [[ -n "$ev" ]] && printf '%s\n' "$ev"
  } >"$body_file"
  create_issue "$title" "$body_file" "$labels_csv"
done < <(jq -c '.follow_up_issues[]?' "$RETRO_JSON")

echo "Post-merge retro issue creation finished for PR #${PR}"
