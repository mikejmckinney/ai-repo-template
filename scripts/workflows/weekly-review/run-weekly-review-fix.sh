#!/usr/bin/env bash
# Implement weekly review findings and open/update a draft fix PR.
# Usage: run-weekly-review-fix.sh <weekly-review.json>
set -euo pipefail
umask 077

WEEKLY_JSON="${1:-}"
usage() {
  echo "Usage: run-weekly-review-fix.sh <weekly-review.json>" >&2
  exit 2
}
[[ -n "$WEEKLY_JSON" && -f "$WEEKLY_JSON" ]] || usage

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
SCRIPT_DIR="$REPO_ROOT/scripts/workflows/weekly-review"
RETRO_DIR="$REPO_ROOT/scripts/workflows/postmerge-retro"
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

python3 "$SCRIPT_DIR/validate-weekly-review-batch.py" "$WEEKLY_JSON"
RUN_WEEK="$(jq -r .run_week "$WEEKLY_JSON")"
RUN_DATE="$(jq -r .run_date "$WEEKLY_JSON")"
python3 "$RETRO_DIR/mark-superseded-findings.py" \
  "$WEEKLY_JSON" --repo-root "$REPO_ROOT" --mode weekly
VERIFY_JSON="$REPO_ROOT/weekly/fix-verify-${RUN_WEEK}.json"
SANDBOX_BRANCH="test/fix-weekly-${RUN_WEEK}"
FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-weekly-findings.py" "$WEEKLY_JSON")"
if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "Zero findings; skipping fix PR"
  exit 0
fi

BRANCH="weekly/fix-${RUN_WEEK}"

if [[ -z "${WEEKLY_REVIEW_FIX_REEXEC:-}" ]]; then
  export WEEKLY_REVIEW_FIX_REEXEC=1
  FIX_REEXEC_DIR="${REPO_ROOT}/.artifacts/weekly-review/fix-reexec-${RUN_WEEK}"
  mkdir -p "$FIX_REEXEC_DIR"
  cp "$SCRIPT_DIR/run-weekly-review-fix.sh" "$FIX_REEXEC_DIR/fix-runner.sh"
  exec bash "$FIX_REEXEC_DIR/fix-runner.sh" "$@"
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# shellcheck source=../lib/fix-phase-log.sh
source "$LIB_DIR/fix-phase-log.sh"
# shellcheck source=../lib/run-batch-fix.sh
source "$LIB_DIR/run-batch-fix.sh"
fix_phase_log_init

git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"

# shellcheck source=../lib/checkout-fix-branch.sh
source "$LIB_DIR/checkout-fix-branch.sh"
checkout_fix_branch "$REPO" "$BRANCH"
existing_pr="${CHECKOUT_FIX_OPEN_PR_NUM:-}"
fix_phase_log "checkout"

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/weekly-repo-review-fix.md"
  echo ""
  echo "---"
  echo ""
  echo "## Automation context"
  echo ""
  echo "- Repository: \`${REPO}\`"
  echo "- Run week: ${RUN_WEEK}"
  echo "- Run date: ${RUN_DATE}"
  echo "- Branch: \`${BRANCH}\`"
  echo "- Findings count: ${FINDINGS_COUNT}"
  echo "- FIX_JOB_SANDBOX_VERIFY: ${FIX_JOB_SANDBOX_VERIFY:-false}"
  echo ""
  echo "### Superseded findings (automation pre-check on main HEAD)"
  echo ""
  superseded="$(jq -c '.superseded_findings // []' "$WEEKLY_JSON")"
  if [[ "$superseded" == "[]" ]]; then
    echo "_None detected._"
  else
    echo '```json'
    echo "$superseded"
    echo '```'
  fi
  echo ""
  echo "### weekly-review.json"
  echo ""
  echo '```json'
  cat "$WEEKLY_JSON"
  echo '```'
} >"$prompt_file"

# shellcheck source=../lib/pick-advisory-provider.sh
source "$LIB_DIR/pick-advisory-provider.sh"
# shellcheck source=../lib/invoke-advisory-llm.sh
source "$LIB_DIR/invoke-advisory-llm.sh"
# shellcheck source=../lib/run-fix-provider-cascade.sh
source "$LIB_DIR/run-fix-provider-cascade.sh"

init_advisory_provider_credentials
llm_raw="$WORKDIR/llm-fix-output.txt"

apply_weekly_gemini_fix() {
  local raw_output="$1" attempt_repo="$2"
  local fix_json="$WORKDIR/fix.json" dated_json="$WORKDIR/fix-with-week.json"
  python3 "$RETRO_DIR/extract-retro-fix-json.py" "$raw_output" "$fix_json" \
    && jq --arg rw "$RUN_WEEK" --arg rd "$RUN_DATE" \
      '. + {run_week: $rw, run_date: $rd}' "$fix_json" >"$dated_json" \
    && python3 "$RETRO_DIR/apply-retro-fix-json.py" "$dated_json" "$attempt_repo"
}

run_fix_provider_cascade weekly-fix "$prompt_file" "$llm_raw" "$REPO_ROOT" \
  "$ADVISORY_DIR" "$WORKDIR" "$LIB_DIR" apply_weekly_gemini_fix \
  "$WEEKLY_JSON" "weekly/fix-verify-${RUN_WEEK}.json"
fix_phase_log "llm-fix"

batch_fix_strip_workflow_changes

# shellcheck source=../lib/finalize-fix-pr.sh
source "$LIB_DIR/finalize-fix-pr.sh"
maybe_sandbox_sync "$REPO_ROOT" "$SANDBOX_BRANCH" "[sandbox] Weekly review fix ${RUN_WEEK}" "$VERIFY_JSON" "$LIB_DIR"
fix_phase_log "sandbox-sync"

batch_fix_commit_changes "fix: weekly repo review fixes for ${RUN_WEEK}" "" "$VERIFY_JSON"
has_diff="$BATCH_FIX_HAS_DIFF"
fix_phase_log "commit"

render_fix_pr_body() {
  local body_file="$WORKDIR/fix-pr-body.md"
  local umbrella_num umbrella_url umbrella_ref verify_sections_file
  cp "$REPO_ROOT/.github/templates/weekly-review-fix-pr.md" "$body_file"
  umbrella_num="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_WEEK" "$WEEKLY_JSON" 2>/dev/null || true)"
  if [[ -n "$umbrella_num" ]]; then
    umbrella_url="$(gh issue view "$umbrella_num" -R "$REPO" --json url --jq .url)"
    umbrella_ref="#${umbrella_num}"
  else
    umbrella_url="(pending — umbrella job may still be running)"
    umbrella_ref="(umbrella pending)"
    umbrella_num=""
  fi
  sed -i \
    -e "s/{{RUN_WEEK}}/${RUN_WEEK}/g" \
    -e "s/{{FINDINGS_COUNT}}/${FINDINGS_COUNT}/g" \
    -e "s|{{UMBRELLA_ISSUE_LINK}}|${umbrella_url}|g" \
    -e "s|{{UMBRELLA_ISSUE_REF}}|${umbrella_ref}|g" \
    -e "s|{{UMBRELLA_ISSUE_NUM}}|${umbrella_num}|g" \
    -e "s|{{FIX_BRANCH}}|${BRANCH}|g" \
    -e "s|{{REPO}}|${REPO}|g" \
    -e '/^{{FIX_VERIFY_SECTIONS}}$/d' \
    "$body_file"
  if [[ -z "$umbrella_num" ]]; then
    sed -i '/^Fixes #[[:space:]]*$/d' "$body_file"
  fi
  verify_sections_file="$WORKDIR/verify-sections.md"
  python3 "$LIB_DIR/render-fix-pr-sections.py" "$VERIFY_JSON" all >"$verify_sections_file" 2>/dev/null \
    || finalize_append_verify_sections "$verify_sections_file" "$VERIFY_JSON" "$LIB_DIR"
  cat "$verify_sections_file" >>"$body_file"
}

batch_fix_publish \
  "$REPO" "$BRANCH" "$existing_pr" "$has_diff" "$RUN_WEEK" "$WEEKLY_JSON" \
  "Weekly repo review fix: ${RUN_WEEK}" "$WORKDIR/fix-pr-body.md" render_fix_pr_body \
  "$SCRIPT_DIR/update-umbrella-fix-link.sh" "$SCRIPT_DIR/resolve-umbrella-issue.sh" \
  "$LIB_DIR/link-fix-pr-to-issue.sh" "$VERIFY_JSON"

echo "Fix pass complete for ${RUN_WEEK}"
