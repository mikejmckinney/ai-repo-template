#!/usr/bin/env bash
# Daily post-merge retro: scan merges in last 24h, per-PR retro, umbrella issue.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
ARTIFACT_ROOT="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/daily-${RUN_DATE}"
mkdir -p "$ARTIFACT_ROOT"

mapfile -t ALL_PRS < <(bash "$SCRIPT_DIR/list-merges-last-24h.sh" || true)
if [[ -n "${POSTMERGE_RETRO_ONLY_PRS:-}" ]]; then
  mapfile -t ALL_PRS < <(tr ',' '\n' <<<"${POSTMERGE_RETRO_ONLY_PRS}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d')
  echo "POSTMERGE_RETRO_ONLY_PRS override: ${ALL_PRS[*]}"
fi
if [[ ${#ALL_PRS[@]} -eq 0 ]]; then
  echo "No merges to main in the last 24h; skipping daily retro"
  echo "0" >"$ARTIFACT_ROOT/findings-count.txt"
  exit 0
fi

echo "Merged PRs in window: ${ALL_PRS[*]}"

# Skip PRs already listed in today's umbrella (append semantics).
SKIP_PRS=()
EXISTING_ISSUE=""
if existing_num="$(bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_DATE" 2>/dev/null)"; then
  EXISTING_ISSUE="$(gh issue view "$existing_num" -R "${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}" --json body --jq .body 2>/dev/null || true)"
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

RETRO_FILES=()
for pr in "${ALL_PRS[@]}"; do
  skip=false
  for s in "${SKIP_PRS[@]:-}"; do
    [[ "$s" == "$pr" ]] && skip=true && break
  done
  if $skip; then
    echo "Skip PR #${pr} (already in umbrella for ${RUN_DATE})"
    continue
  fi
  echo "Running retro for PR #${pr}..."
  bash "$SCRIPT_DIR/run-postmerge-retro.sh" "$pr" false
  pr_artifact="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/pr-${pr}/retro.json"
  if [[ ! -f "$pr_artifact" ]]; then
    echo "::warning::Missing retro.json for PR #${pr}; skipping"
    continue
  fi
  cp -f "$pr_artifact" "$ARTIFACT_ROOT/pr-${pr}-retro.json"
  RETRO_FILES+=("$ARTIFACT_ROOT/pr-${pr}-retro.json")
done

if [[ ${#RETRO_FILES[@]} -eq 0 ]]; then
  echo "No new PR retros produced; skipping merge/umbrella"
  echo "0" >"$ARTIFACT_ROOT/findings-count.txt"
  exit 0
fi

DAILY_JSON="$ARTIFACT_ROOT/daily-retro.json"
python3 "$SCRIPT_DIR/merge-daily-retro-json.py" "$RUN_DATE" "${RETRO_FILES[@]}" >"$DAILY_JSON"
python3 "$SCRIPT_DIR/validate-postmerge-retro-daily.py" "$DAILY_JSON"

bash "$SCRIPT_DIR/create-umbrella-issue.sh" "$DAILY_JSON"

FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-daily-retro-findings.py" "$DAILY_JSON")"
echo "$FINDINGS_COUNT" >"$ARTIFACT_ROOT/findings-count.txt"
echo "Daily retro complete for ${RUN_DATE} (${FINDINGS_COUNT} findings)"
