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
VERIFY_JSON="$REPO_ROOT/retro/fix-verify-${RUN_DATE}.json"
SANDBOX_BRANCH="test/fix-retro-${RUN_DATE}"
FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-daily-retro-findings.py" "$DAILY_JSON")"
if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "Zero findings; skipping fix PR"
  exit 0
fi

BRANCH="retro/fix-${RUN_DATE}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# shellcheck source=../lib/fix-phase-log.sh
source "$LIB_DIR/fix-phase-log.sh"
fix_phase_log_init

if [[ -z "${POSTMERGE_RETRO_FIX_REEXEC:-}" ]]; then
  export POSTMERGE_RETRO_FIX_REEXEC=1
  cp "$SCRIPT_DIR/run-postmerge-retro-fix.sh" "$WORKDIR/fix-runner.sh"
  exec bash "$WORKDIR/fix-runner.sh" "$@"
fi

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
  echo "For Cursor/local mode, edit the repo directly."
  echo "For Gemini JSON mode, respond with JSON only (file_edits + commit_message + fix_verify)."
} >"$prompt_file"

has_cursor=0
has_gemini=0
[[ -n "${CURSOR_API_KEY:-}" ]] && has_cursor=1
[[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]] && has_gemini=1

strip_workflow_changes() {
  local paths=()
  while IFS= read -r -d '' f; do
    paths+=("$f")
  done < <(git status --porcelain .github/workflows/ 2>/dev/null | awk '{print $2}' | tr '\n' '\0')
  if ((${#paths[@]} == 0)); then
    return 0
  fi
  echo "::notice::Stripping ${#paths[@]} .github/workflows/ change(s) from fix commit (token lacks workflows:write). Document in fix-verify.json verify.notes if needed." >&2
  for f in "${paths[@]}"; do
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      git checkout HEAD -- "$f"
    else
      rm -f "$f"
    fi
  done
}

# shellcheck source=../lib/pick-advisory-provider.sh
source "$LIB_DIR/pick-advisory-provider.sh"
# shellcheck source=../lib/invoke-advisory-llm.sh
source "$LIB_DIR/invoke-advisory-llm.sh"

PROVIDER="$(pick_advisory_provider retro-fix)"
[[ -n "$PROVIDER" ]] || {
  echo "::error::No fix provider configured"
  exit 1
}

llm_raw="$WORKDIR/llm-fix-output.txt"
invoke_advisory_llm "$prompt_file" "$llm_raw" "$PROVIDER" "$ADVISORY_DIR" "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"
fix_phase_log "llm-fix"

case "$PROVIDER" in
  gemini)
    fix_json="$WORKDIR/fix.json"
    python3 "$SCRIPT_DIR/extract-retro-fix-json.py" "$llm_raw" "$fix_json"
    jq --arg rd "$RUN_DATE" '. + {run_date: $rd}' "$fix_json" >"$WORKDIR/fix-with-date.json"
    python3 "$SCRIPT_DIR/apply-retro-fix-json.py" "$WORKDIR/fix-with-date.json" "$REPO_ROOT"
    ;;
esac

if [[ ! -f "$VERIFY_JSON" ]]; then
  echo "::warning::fix-verify.json missing after fix pass; creating minimal stub" >&2
  python3 - "$VERIFY_JSON" "$RUN_DATE" "$DAILY_JSON" <<'PY'
import json
import sys
from pathlib import Path

out, run_date, daily_path = sys.argv[1:4]
daily = json.loads(Path(daily_path).read_text(encoding="utf-8"))
rows = []
for item in daily.get("findings") or []:
    if item.get("category") != "follow_up_issues":
        continue
    rows.append(
        {
            "dedupe_key": item.get("dedupe_key", ""),
            "repro_steps": item.get("repro_steps") or [],
            "verify": {
                "pre": "pending",
                "post": "pending",
                "sandbox": "n/a",
                "notes": "stub — fix agent did not write fix-verify.json",
            },
        }
    )
payload = {
    "run_date": run_date,
    "run_kind": "retro",
    "findings": rows,
    "sandbox": {
        "needs_sync": False,
        "issue_url": "n/a",
        "pr_url": "n/a",
        "skip_reason": "fix-verify stub",
        "workflow_runs": [],
    },
    "test_sh": "unknown",
}
Path(out).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
fi

strip_workflow_changes

# shellcheck source=../lib/finalize-fix-pr.sh
source "$LIB_DIR/finalize-fix-pr.sh"
maybe_sandbox_sync "$REPO_ROOT" "$SANDBOX_BRANCH" "[sandbox] Post-merge retro fix ${RUN_DATE}" "$VERIFY_JSON" "$LIB_DIR"
fix_phase_log "sandbox-sync"

has_diff=0
if ! git diff --quiet || ! git diff --cached --quiet; then
  commit_msg="fix: post-merge retro daily fixes for ${RUN_DATE}"
  if [[ -f "$REPO_ROOT/.artifacts/postmerge-retro/fix-commit-message.txt" ]]; then
    commit_msg="$(head -1 "$REPO_ROOT/.artifacts/postmerge-retro/fix-commit-message.txt")"
  fi
  git add -A
  git reset HEAD -- .github/workflows/ 2>/dev/null || true
  git checkout HEAD -- .github/workflows/ 2>/dev/null || true
  git commit -m "$commit_msg"
  has_diff=1
else
  echo "::warning::Fix pass produced no git diff"
fi
fix_phase_log "commit"

if [[ "$has_diff" -eq 1 ]]; then
  git push -u origin "$BRANCH"
elif [[ -z "$existing_pr" ]]; then
  skip_notice="(skipped — no code changes; see fix-verify.json if present)"
  bash "$SCRIPT_DIR/update-umbrella-fix-link.sh" "$RUN_DATE" "$skip_notice" "$DAILY_JSON"
  echo "Fix pass complete for ${RUN_DATE} (no changes)"
  fix_phase_log "publish"
  exit 0
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

link_pr_to_umbrella() {
  local pr_ref="$1"
  local pr_num umbrella_num
  pr_num="${pr_ref##*/}"
  [[ "$pr_num" =~ ^[0-9]+$ ]] || return 0
  umbrella_num="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_DATE" "$DAILY_JSON" 2>/dev/null || true)"
  [[ -n "$umbrella_num" ]] || return 0
  bash "$LIB_DIR/link-fix-pr-to-issue.sh" "$REPO" "$pr_num" "$umbrella_num"
}

if [[ -n "$existing_pr" ]]; then
  echo "Open draft PR already exists: #${existing_pr}"
  PR_URL="$(gh pr view "$existing_pr" -R "$REPO" --json url --jq .url)"
  render_fix_pr_body
  gh pr edit "$existing_pr" -R "$REPO" --body-file "$WORKDIR/fix-pr-body.md"
else
  render_fix_pr_body
  PR_URL="$(gh pr create -R "$REPO" \
    --base main \
    --head "$BRANCH" \
    --draft \
    --title "Post-merge retro fix: ${RUN_DATE}" \
    --body-file "$WORKDIR/fix-pr-body.md")"
  echo "Created draft PR: ${PR_URL}"
fi

link_pr_to_umbrella "$PR_URL"
bash "$SCRIPT_DIR/update-umbrella-fix-link.sh" "$RUN_DATE" "$PR_URL" "$DAILY_JSON"
fix_phase_log "publish"

echo "Fix pass complete for ${RUN_DATE}"
