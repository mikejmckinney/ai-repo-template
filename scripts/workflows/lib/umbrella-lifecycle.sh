#!/usr/bin/env bash
# Shared issue transport and reference handling for batch umbrella issues.

umbrella_is_issue_number() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

umbrella_find_issue() {
  local repo="$1" search_term="$2" marker="$3" marker_family="$4"
  local candidate body

  while read -r candidate; do
    [[ -z "$candidate" ]] && continue
    if gh api "repos/${repo}/issues/${candidate}" --jq -e '.pull_request != null' >/dev/null 2>&1; then
      continue
    fi
    body="$(gh issue view "$candidate" -R "$repo" --json body --jq .body 2>/dev/null || true)"
    [[ -n "$body" ]] || continue
    if grep -Fq "$marker" <<<"$body" && grep -Eq "$marker_family" <<<"$body"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(gh search issues "$search_term" --repo "$repo" --json number --limit 10 --jq '.[].number' 2>/dev/null || true)

  return 1
}

umbrella_resolve_issue() {
  local cadence_key="$1" json_path="$2" finder_script="$3"
  local issue_num sidecar

  if [[ -n "${UMBRELLA_ISSUE_NUM:-}" ]]; then
    issue_num="$(tr -d '[:space:]' <<<"$UMBRELLA_ISSUE_NUM")"
    umbrella_is_issue_number "$issue_num" || return 1
    printf '%s\n' "$issue_num"
    return 0
  fi

  if [[ -n "$json_path" && -f "$json_path" ]]; then
    issue_num="$(jq -r '.umbrella_issue // empty' "$json_path" 2>/dev/null || true)"
    if umbrella_is_issue_number "$issue_num"; then
      printf '%s\n' "$issue_num"
      return 0
    fi
    sidecar="$(dirname "$json_path")/umbrella-issue.txt"
    if [[ -f "$sidecar" ]]; then
      issue_num="$(tr -d '[:space:]' <"$sidecar")"
      if umbrella_is_issue_number "$issue_num"; then
        printf '%s\n' "$issue_num"
        return 0
      fi
    fi
  fi

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    issue_num="$(GH_TOKEN="$GITHUB_TOKEN" bash "$finder_script" "$cadence_key" 2>/dev/null || true)"
    if umbrella_is_issue_number "$issue_num"; then
      printf '%s\n' "$issue_num"
      return 0
    fi
  fi

  issue_num="$(bash "$finder_script" "$cadence_key" 2>/dev/null || true)"
  umbrella_is_issue_number "$issue_num" || return 1
  printf '%s\n' "$issue_num"
}

umbrella_write_issue_ref() {
  local json_path="$1" issue_num="$2"
  shift 2
  local json_temp sidecar sidecar_temp

  issue_num="$(tr -d '[:space:]' <<<"$issue_num")"
  umbrella_is_issue_number "$issue_num" || {
    echo "::error::issue-number must be a positive integer: '${issue_num}'" >&2
    return 1
  }

  json_temp="$(mktemp "$(dirname "$json_path")/.umbrella-json.XXXXXX")"
  sidecar="$(dirname "$json_path")/umbrella-issue.txt"
  sidecar_temp="$(mktemp "$(dirname "$json_path")/.umbrella-sidecar.XXXXXX")"
  if ! jq --argjson number "$issue_num" '. + {umbrella_issue: $number}' "$json_path" >"$json_temp"; then
    rm -f "$json_temp" "$sidecar_temp"
    return 1
  fi
  printf '%s\n' "$issue_num" >"$sidecar_temp"
  mv "$json_temp" "$json_path"
  mv "$sidecar_temp" "$sidecar"
  "$@" "$json_path"
}

umbrella_require_marker() {
  local body="$1" marker="$2" issue_num="$3"
  grep -Fq "$marker" <<<"$body" || {
    echo "::error::Issue #${issue_num} missing umbrella marker" >&2
    return 1
  }
}

umbrella_edit_issue_body() {
  local repo="$1" issue_num="$2" body_file="$3"
  gh issue edit "$issue_num" -R "$repo" --body-file "$body_file" >/dev/null
}

umbrella_create_issue() {
  local repo="$1" title="$2" body_file="$3" label="${4:-}"
  local issue_url issue_num

  issue_url="$(gh issue create -R "$repo" --title "$title" --body-file "$body_file")"
  issue_num="${issue_url##*/}"
  umbrella_is_issue_number "$issue_num" || {
    echo "::error::Created umbrella URL has invalid issue number: '${issue_url}'" >&2
    return 1
  }
  if [[ -n "$label" ]]; then
    if gh issue edit "$issue_num" -R "$repo" --add-label "$label" >/dev/null 2>&1; then
      echo "Created umbrella issue #${issue_num} (${label})" >&2
    else
      echo "::notice::Umbrella issue #${issue_num} created without ${label} label" >&2
    fi
  fi
  printf '%s\n' "$issue_num"
}

umbrella_update_fix_link() {
  local repo="$1" issue_num="$2" marker="$3" fix_reference="$4"
  local body workdir

  body="$(gh issue view "$issue_num" -R "$repo" --json body --jq .body)"
  umbrella_require_marker "$body" "$marker" "$issue_num"
  if grep -Fq "$fix_reference" <<<"$body"; then
    echo "Umbrella issue #${issue_num} already links fix PR"
    return 0
  fi

  workdir="$(mktemp -d)"
  printf '%s' "$body" >"$workdir/body.md"
  python3 - "$workdir/body.md" "$fix_reference" >"$workdir/body-updated.md" <<'PY'
import re
import sys
from pathlib import Path

body = Path(sys.argv[1]).read_text(encoding="utf-8")
fix_reference = sys.argv[2]
pending = "(pending — fix job)"
link_line = f"Draft fix PR (if created): {fix_reference}"
if pending in body:
    body = body.replace(pending, fix_reference, 1)
elif re.search(r"Draft fix PR \(if created\):\s*\S+", body):
    body = re.sub(
        r"Draft fix PR \(if created\):\s*[^\n]+",
        link_line,
        body,
        count=1,
    )
else:
    body = body.rstrip() + f"\n{link_line}\n"
print(body)
PY
  umbrella_edit_issue_body "$repo" "$issue_num" "$workdir/body-updated.md"
  rm -rf "$workdir"
  echo "Updated umbrella issue #${issue_num} with fix PR link"
}
