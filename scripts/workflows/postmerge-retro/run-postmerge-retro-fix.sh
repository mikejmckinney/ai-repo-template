#!/usr/bin/env bash
# Implement daily retro findings and open/update a draft fix PR.
# Usage: run-postmerge-retro-fix.sh <daily-retro.json>
set -euo pipefail
umask 077

DAILY_JSON="${1:-}"
usage() {
  echo "Usage: run-postmerge-retro-fix.sh <daily-retro.json>" >&2
  exit 2
}
[[ -n "$DAILY_JSON" && -f "$DAILY_JSON" ]] || usage

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
SCRIPT_DIR="$REPO_ROOT/scripts/workflows/postmerge-retro"
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

python3 "$SCRIPT_DIR/validate-postmerge-retro-daily.py" "$DAILY_JSON"
RUN_DATE="$(jq -r .run_date "$DAILY_JSON")"
python3 "$SCRIPT_DIR/mark-superseded-findings.py" "$DAILY_JSON" --repo-root "$REPO_ROOT"
VERIFY_JSON="$REPO_ROOT/retro/fix-verify-${RUN_DATE}.json"
SANDBOX_BRANCH="test/fix-retro-${RUN_DATE}"
FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-daily-retro-findings.py" "$DAILY_JSON")"
if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "Zero findings; skipping fix PR"
  exit 0
fi

BRANCH="retro/fix-${RUN_DATE}"

if [[ -z "${POSTMERGE_RETRO_FIX_REEXEC:-}" ]]; then
  export POSTMERGE_RETRO_FIX_REEXEC=1
  FIX_REEXEC_DIR="${REPO_ROOT}/.artifacts/postmerge-retro/fix-reexec-${RUN_DATE}"
  mkdir -p "$FIX_REEXEC_DIR"
  cp "$SCRIPT_DIR/run-postmerge-retro-fix.sh" "$FIX_REEXEC_DIR/fix-runner.sh"
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
  cat "$REPO_ROOT/.github/prompts/post-merge-retro-fix.md"
  echo ""
  echo "---"
  echo ""
  echo "## Automation context"
  echo ""
  echo "- Repository: \`${REPO}\`"
  echo "- Run date: ${RUN_DATE}"
  echo "- Branch: \`${BRANCH}\`"
  echo "- Findings count: ${FINDINGS_COUNT}"
  echo "- FIX_JOB_SANDBOX_VERIFY: ${FIX_JOB_SANDBOX_VERIFY:-false}"
  echo ""
  echo "### Superseded findings (automation pre-check on main HEAD)"
  echo ""
  superseded="$(jq -c '.superseded_findings // []' "$DAILY_JSON")"
  if [[ "$superseded" == "[]" ]]; then
    echo "_None detected._"
  else
    echo '```json'
    echo "$superseded"
    echo '```'
  fi
  echo ""
  echo "### daily-retro.json"
  echo ""
  echo '```json'
  cat "$DAILY_JSON"
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "## Instruction"
  echo ""
  echo "Review the current branch state against each finding (by \`dedupe_key\`); implement only findings not yet addressed on \`${BRANCH}\`."
  echo "Write \`retro/fix-verify-${RUN_DATE}.json\` with per-finding verify outcomes before finishing."
  echo "For OpenCode/Cursor local mode, edit the repo directly."
  echo "For Gemini JSON mode, respond with JSON only (file_edits + commit_message + fix_verify)."
} >"$prompt_file"

# shellcheck source=../lib/pick-advisory-provider.sh
source "$LIB_DIR/pick-advisory-provider.sh"
# shellcheck source=../lib/invoke-advisory-llm.sh
source "$LIB_DIR/invoke-advisory-llm.sh"
# shellcheck source=../lib/run-fix-provider-cascade.sh
source "$LIB_DIR/run-fix-provider-cascade.sh"

init_advisory_provider_credentials
llm_raw="$WORKDIR/llm-fix-output.txt"

apply_daily_gemini_fix() {
  local raw_output="$1" attempt_repo="$2"
  local fix_json="$WORKDIR/fix.json" dated_json="$WORKDIR/fix-with-date.json"
  python3 "$SCRIPT_DIR/extract-retro-fix-json.py" "$raw_output" "$fix_json" \
    && jq --arg rd "$RUN_DATE" '. + {run_date: $rd}' "$fix_json" >"$dated_json" \
    && python3 "$SCRIPT_DIR/apply-retro-fix-json.py" "$dated_json" "$attempt_repo"
}

run_fix_provider_cascade retro-fix "$prompt_file" "$llm_raw" "$REPO_ROOT" \
  "$ADVISORY_DIR" "$WORKDIR" "$LIB_DIR" apply_daily_gemini_fix \
  "$DAILY_JSON" "retro/fix-verify-${RUN_DATE}.json"
fix_phase_log "llm-fix"

batch_fix_strip_workflow_changes

# shellcheck source=../lib/finalize-fix-pr.sh
source "$LIB_DIR/finalize-fix-pr.sh"
batch_fix_commit_changes \
  "fix: post-merge retro daily fixes for ${RUN_DATE}" \
  "$REPO_ROOT/.artifacts/postmerge-retro/fix-commit-message.txt" "$VERIFY_JSON"
has_diff="$BATCH_FIX_HAS_DIFF"
fix_phase_log "commit"

if [[ "$has_diff" -eq 1 ]]; then
  maybe_sandbox_sync "$REPO_ROOT" "$SANDBOX_BRANCH" "[sandbox] Post-merge retro fix ${RUN_DATE}" "$VERIFY_JSON" "$LIB_DIR"
  fix_phase_log "sandbox-sync"
  batch_fix_commit_verification_update \
    "$VERIFY_JSON" "chore: record sandbox outcome evidence for ${RUN_DATE}"
  fix_phase_log "evidence-commit"
fi

render_fix_pr_body() {
  local body_file="$WORKDIR/fix-pr-body.md"
  local umbrella_num umbrella_url umbrella_ref verify_sections_file
  cp "$REPO_ROOT/.github/templates/postmerge-retro-fix-pr.md" "$body_file"
  umbrella_num="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_DATE" "$DAILY_JSON" 2>/dev/null || true)"
  if [[ -n "$umbrella_num" ]]; then
    umbrella_url="$(gh issue view "$umbrella_num" -R "$REPO" --json url --jq .url)"
    umbrella_ref="#${umbrella_num}"
  else
    umbrella_url="(pending — umbrella job may still be running)"
    umbrella_ref="(umbrella pending)"
  fi
  sed -i \
    -e "s/{{RUN_DATE}}/${RUN_DATE}/g" \
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
  "$REPO" "$BRANCH" "$existing_pr" "$has_diff" "$RUN_DATE" "$DAILY_JSON" \
  "Post-merge retro fix: ${RUN_DATE}" "$WORKDIR/fix-pr-body.md" render_fix_pr_body \
  "$SCRIPT_DIR/update-umbrella-fix-link.sh" "$SCRIPT_DIR/resolve-umbrella-issue.sh" \
  "$LIB_DIR/link-fix-pr-to-issue.sh" "$VERIFY_JSON"

echo "Fix pass complete for ${RUN_DATE}"
