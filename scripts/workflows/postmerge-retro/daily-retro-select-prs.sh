#!/usr/bin/env bash
# Select merged PRs for a daily retro batch (stdout: one PR number per line).
# Shared by sequential, monolithic, and parallel daily runners.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"

mapfile -t ALL_PRS < <(bash "$SCRIPT_DIR/list-merges-last-24h.sh" || true)
if [[ -n "${POSTMERGE_RETRO_ONLY_PRS:-}" ]]; then
  mapfile -t ALL_PRS < <(tr ',' '\n' <<<"${POSTMERGE_RETRO_ONLY_PRS}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d')
  echo "POSTMERGE_RETRO_ONLY_PRS override: ${ALL_PRS[*]}" >&2
fi
if [[ ${#ALL_PRS[@]} -eq 0 ]]; then
  exit 0
fi

echo "Merged PRs in window: ${ALL_PRS[*]}" >&2

FORCE_PRS=()
if [[ -n "${POSTMERGE_RETRO_FORCE_RE_RETRO_PRS:-}" ]]; then
  mapfile -t FORCE_PRS < <(tr ',' '\n' <<<"${POSTMERGE_RETRO_FORCE_RE_RETRO_PRS}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d')
  echo "POSTMERGE_RETRO_FORCE_RE_RETRO_PRS override: ${FORCE_PRS[*]}" >&2
fi

is_force_pr() {
  local pr="$1"
  for f in "${FORCE_PRS[@]:-}"; do
    [[ "$f" == "$pr" ]] && return 0
  done
  return 1
}

INDEXED_MERGES=()
if [[ "${POSTMERGE_RETRO_IGNORE_RETRO_DEDUPE:-}" != "true" ]]; then
  mapfile -t INDEXED_MERGES < <(bash "$SCRIPT_DIR/list-indexed-merge-shas.sh" || true)
  if ((${#INDEXED_MERGES[@]} > 0)); then
    echo "Indexed merge_commit_sha count: ${#INDEXED_MERGES[@]}" >&2
  fi
else
  echo "POSTMERGE_RETRO_IGNORE_RETRO_DEDUPE=true; skipping merge_commit_sha dedupe" >&2
fi

is_indexed_merge() {
  local sha="${1,,}"
  for existing in "${INDEXED_MERGES[@]:-}"; do
    [[ "${existing,,}" == "$sha" ]] && return 0
  done
  return 1
}

SKIP_PRS=()
EXISTING_ISSUE=""
if existing_num="$(bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_DATE" 2>/dev/null)"; then
  EXISTING_ISSUE="$(gh issue view "$existing_num" -R "$REPO" --json body --jq .body 2>/dev/null || true)"
fi
if [[ -n "$EXISTING_ISSUE" ]]; then
  while IFS= read -r pr; do
    [[ -z "$pr" ]] && continue
    if grep -Eq "\| #${pr} \|" <<<"$EXISTING_ISSUE" \
      || grep -Eq "PRs in this update:.*#${pr}([, ]|$)" <<<"$EXISTING_ISSUE"; then
      SKIP_PRS+=("$pr")
    fi
  done < <(printf '%s\n' "${ALL_PRS[@]}")
fi

for pr in "${ALL_PRS[@]}"; do
  skip=false
  for s in "${SKIP_PRS[@]:-}"; do
    [[ "$s" == "$pr" ]] && skip=true && break
  done
  if $skip; then
    echo "Skip PR #${pr} (already in umbrella for ${RUN_DATE})" >&2
    continue
  fi

  merge_sha="$(gh pr view "$pr" -R "$REPO" --json mergeCommit --jq '.mergeCommit.oid // empty' 2>/dev/null || true)"
  if [[ -z "$merge_sha" ]]; then
    merge_sha="$(gh pr view "$pr" -R "$REPO" --json merge_commit_sha --jq '.merge_commit_sha // empty' 2>/dev/null || true)"
  fi
  if [[ -n "$merge_sha" ]] && is_indexed_merge "$merge_sha" && ! is_force_pr "$pr"; then
    echo "Skip PR #${pr} (merge_commit_sha ${merge_sha} already indexed)" >&2
    continue
  fi
  if is_force_pr "$pr"; then
    echo "Force re-retro for PR #${pr} (POSTMERGE_RETRO_FORCE_RE_RETRO_PRS)" >&2
  fi
  printf '%s\n' "$pr"
done
