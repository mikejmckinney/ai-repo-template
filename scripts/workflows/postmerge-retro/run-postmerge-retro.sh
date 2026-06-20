#!/usr/bin/env bash
# scripts/workflows/postmerge-retro/run-postmerge-retro.sh — post-merge retro dispatch.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PR="${1:-${PR_NUMBER:-}}"
CREATE_ISSUES="${2:-${CREATE_ISSUES:-true}}"

usage() {
  echo "Usage: run-postmerge-retro.sh <pr-number> [create_issues=true|false]" >&2
  exit 2
}

[[ -n "$PR" ]] || usage

parse_positive_int() {
  local name="$1" default="$2" raw="${3:-}"
  if [[ -z "$raw" ]]; then
    echo "$default"
    return
  fi
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ $((10#$raw)) -gt 0 ]]; then
    echo "$((10#$raw))"
    return
  fi
  echo "::warning::Invalid ${name}=${raw}; using default ${default}" >&2
  echo "$default"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DEFAULT_DIFF_LIMIT=300000
diff_limit="$(parse_positive_int POSTMERGE_RETRO_DIFF_LIMIT "$DEFAULT_DIFF_LIMIT" "${POSTMERGE_RETRO_DIFF_LIMIT:-}")"

bash "$SCRIPT_DIR/collect-postmerge-evidence.sh" "$PR" "$WORKDIR"

COVERAGE_JSON="$WORKDIR/evidence-coverage.json"
python3 "$SCRIPT_DIR/compute-evidence-coverage.py" "$WORKDIR" \
  --pr "$PR" \
  --repo-root "$REPO_ROOT" \
  --diff-limit "$diff_limit" \
  --head-file-cap 12000 \
  --head-total-cap 120000 \
  --warn \
  -o "$COVERAGE_JSON"

merged_at="$(jq -r '.merged_at // ""' "$WORKDIR/pr.json")"
if [[ -z "$merged_at" || "$merged_at" == "null" ]]; then
  echo "::error::PR #${PR} is not merged (merged_at=${merged_at})"
  exit 1
fi

MERGE_SHA="$(jq -r '.merge_commit_sha // .head.sha' "$WORKDIR/pr.json")"
jq -r '.body // ""' "$WORKDIR/pr.json" >"$WORKDIR/pr-body.md"

mark_bounded_fallback() {
  python3 "$SCRIPT_DIR/compute-evidence-coverage.py" \
    --warn-record "$COVERAGE_JSON" \
    --set-route bounded-fallback
}

run_bounded_pass() {
  bash "$SCRIPT_DIR/run-postmerge-retro-bounded.sh" "$PR" "$WORKDIR" "$llm_raw" "$COVERAGE_JSON"
}

evidence_route="$(jq -r '.evidence_route // "bounded"' "$COVERAGE_JSON")"
llm_raw="$WORKDIR/llm-output.txt"
provider_used=""

case "$evidence_route" in
  bounded | bounded-fallback)
    run_bounded_pass
    provider_used="$(jq -r '.routing_context.provider_resolved // "bounded"' "$COVERAGE_JSON")"
    ;;
  full-evidence-cursor)
    prompt_file="$WORKDIR/prompt.md"
    bash "$SCRIPT_DIR/assemble-retro-prompt.sh" "$PR" "$WORKDIR" full-evidence "$prompt_file"
    # shellcheck source=../lib/cursor-sdk-version.sh
    source "$LIB_DIR/cursor-sdk-version.sh"
    if npm install --no-save "@cursor/sdk@${CURSOR_SDK_VERSION}" >/dev/null 2>&1 \
      && CURSOR_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}" \
      node "$SCRIPT_DIR/run-postmerge-retro-full-cursor.mjs" "$prompt_file" "$llm_raw"; then
      provider_used="cursor-full-evidence"
    else
      echo "::warning::Full-evidence Cursor retro failed for PR #${PR}; falling back to bounded truncated pass" >&2
      mark_bounded_fallback
      run_bounded_pass
      provider_used="$(jq -r '.routing_context.provider_resolved // "bounded"' "$COVERAGE_JSON")-fallback"
    fi
    ;;
  full-evidence-antigravity)
    prompt_file="$WORKDIR/prompt.md"
    bash "$SCRIPT_DIR/assemble-retro-prompt.sh" "$PR" "$WORKDIR" full-evidence "$prompt_file"
    ag_rc=0
    python3 "$SCRIPT_DIR/run-postmerge-retro-antigravity.py" \
      "$REPO_ROOT" "$WORKDIR" "$prompt_file" "$llm_raw" || ag_rc=$?
    if [[ "$ag_rc" -eq 0 ]]; then
      provider_used="antigravity-full-evidence"
    else
      if [[ "$ag_rc" -eq 3 ]]; then
        echo "::warning::Antigravity retro payload too large for PR #${PR}; falling back to bounded truncated pass" >&2
      else
        echo "::warning::Antigravity full-evidence retro failed for PR #${PR}; falling back to bounded truncated pass" >&2
      fi
      mark_bounded_fallback
      run_bounded_pass
      provider_used="$(jq -r '.routing_context.provider_resolved // "gemini"' "$COVERAGE_JSON")-fallback"
    fi
    ;;
  *)
    echo "::warning::Unknown evidence_route=${evidence_route}; using bounded pass" >&2
    run_bounded_pass
    provider_used="bounded"
    ;;
esac

retro_json="$WORKDIR/retro.json"
python3 "$SCRIPT_DIR/extract-retro-json.py" "$llm_raw" "$PR" "$retro_json"
jq --arg sha "$MERGE_SHA" '. + {merge_commit_sha: $sha}' "$retro_json" >"$WORKDIR/retro-with-sha.json"
mv "$WORKDIR/retro-with-sha.json" "$retro_json"
python3 "$SCRIPT_DIR/validate-postmerge-retro.py" "$retro_json"

final_route="$(jq -r '.evidence_route // "bounded"' "$COVERAGE_JSON")"
cp -f "$retro_json" "$WORKDIR/retro.json.final"
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  artifact_dir="${GITHUB_WORKSPACE}/.artifacts/postmerge-retro/pr-${PR}"
  mkdir -p "$artifact_dir"
  cp -f "$retro_json" "$artifact_dir/retro.json"
  cp -f "$COVERAGE_JSON" "$artifact_dir/evidence-coverage.json" 2>/dev/null || true
  cp -f "$llm_raw" "$artifact_dir/llm-output.txt" 2>/dev/null || true
  cp -f "$WORKDIR/pr.json" "$artifact_dir/pr.json" 2>/dev/null || true
  cp -f "$WORKDIR/changed-files.txt" "$artifact_dir/changed-files.txt" 2>/dev/null || true
fi
echo "Post-merge retro JSON written for PR #${PR} route=${final_route} provider=${provider_used}"

if [[ "$CREATE_ISSUES" == "true" || "$CREATE_ISSUES" == "1" ]]; then
  bash "$SCRIPT_DIR/postmerge-retro-create-issues.sh" "$retro_json"
else
  echo "CREATE_ISSUES=${CREATE_ISSUES}; skipping issue creation"
  cat "$retro_json"
fi

echo "Post-merge retrospective complete for PR #${PR} @ merge ${MERGE_SHA} (route=${final_route})"
