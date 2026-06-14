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
FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-weekly-findings.py" "$WEEKLY_JSON")"
if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "Zero findings; skipping fix PR"
  exit 0
fi

BRANCH="weekly/fix-${RUN_WEEK}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if [[ -z "${WEEKLY_REVIEW_FIX_REEXEC:-}" ]]; then
  export WEEKLY_REVIEW_FIX_REEXEC=1
  cp "$SCRIPT_DIR/run-weekly-review-fix.sh" "$WORKDIR/fix-runner.sh"
  exec bash "$WORKDIR/fix-runner.sh" "$@"
fi

git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"

git fetch origin main
git checkout -B "$BRANCH" origin/main

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
  echo ""
  echo "### weekly-review.json"
  echo ""
  echo '```json'
  cat "$WEEKLY_JSON"
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "## Instruction"
  echo ""
  echo "Implement all findings on branch \`${BRANCH}\`. For Cursor/local mode, edit the repo directly."
  echo "For Gemini JSON mode, respond with JSON only (file_edits + commit_message)."
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
  echo "::notice::Stripping ${#paths[@]} .github/workflows/ change(s) from fix commit (token lacks workflows:write). Document skipped workflow edits in weekly/fix-notes-${RUN_WEEK}.md if needed." >&2
  for f in "${paths[@]}"; do
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      git checkout HEAD -- "$f"
    else
      rm -f "$f"
    fi
  done
}

pick_provider() {
  local want="${WEEKLY_REVIEW_PROVIDER:-${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}}"
  if [[ "$want" == "antigravity" ]]; then
    echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; weekly fix uses auto (cursor, else gemini)." >&2
    want=auto
  fi
  case "$want" in
    cursor) echo cursor ;;
    gemini) echo gemini ;;
    auto)
      if [[ "$has_cursor" -eq 1 ]]; then
        echo cursor
      elif [[ "$has_gemini" -eq 1 ]]; then
        echo gemini
      else
        echo ""
      fi
      ;;
    *) echo "$want" ;;
  esac
}

PROVIDER="$(pick_provider)"
[[ -n "$PROVIDER" ]] || {
  echo "::error::No fix provider configured"
  exit 1
}

llm_raw="$WORKDIR/llm-fix-output.txt"
case "$PROVIDER" in
  cursor)
    npm install --no-save @cursor/sdk >/dev/null 2>&1
    CURSOR_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}}" \
      node "$ADVISORY_DIR/run-advisory-cursor.mjs" "$prompt_file" "$llm_raw"
    ;;
  gemini)
    GEMINI_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}}" \
      python3 "$ADVISORY_DIR/run-advisory-gemini.py" "$prompt_file" "$llm_raw"
    fix_json="$WORKDIR/fix.json"
    python3 "$RETRO_DIR/extract-retro-fix-json.py" "$llm_raw" "$fix_json"
    jq --arg rw "$RUN_WEEK" '. + {run_week: $rw}' "$fix_json" >"$WORKDIR/fix-with-week.json"
    python3 "$RETRO_DIR/apply-retro-fix-json.py" "$WORKDIR/fix-with-week.json" "$REPO_ROOT"
    ;;
esac

strip_workflow_changes

if ! git diff --quiet || ! git diff --cached --quiet; then
  commit_msg="fix: weekly repo review fixes for ${RUN_WEEK}"
  git add -A
  git reset HEAD -- .github/workflows/ 2>/dev/null || true
  git checkout HEAD -- .github/workflows/ 2>/dev/null || true
  git commit -m "$commit_msg"
else
  echo "::warning::Fix pass produced no git diff"
  exit 0
fi

git push -u origin "$BRANCH"

render_fix_pr_body() {
  local body_file="$WORKDIR/fix-pr-body.md"
  local umbrella_num umbrella_url umbrella_ref
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
    "$body_file"
  if [[ -z "$umbrella_num" ]]; then
    sed -i '/^Fixes #[[:space:]]*$/d' "$body_file"
  fi
}

link_pr_to_umbrella() {
  local pr_ref="$1"
  local pr_num umbrella_num
  pr_num="${pr_ref##*/}"
  [[ "$pr_num" =~ ^[0-9]+$ ]] || return 0
  umbrella_num="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_WEEK" "$WEEKLY_JSON" 2>/dev/null || true)"
  [[ -n "$umbrella_num" ]] || return 0
  bash "$LIB_DIR/link-fix-pr-to-issue.sh" "$REPO" "$pr_num" "$umbrella_num"
}

existing_pr="$(gh pr list -R "$REPO" --head "$BRANCH" --state open --json number --jq '.[0].number // empty')"
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
    --title "Weekly repo review fix: ${RUN_WEEK}" \
    --body-file "$WORKDIR/fix-pr-body.md")"
  echo "Created draft PR: ${PR_URL}"
fi

link_pr_to_umbrella "$PR_URL"
bash "$SCRIPT_DIR/update-umbrella-fix-link.sh" "$RUN_WEEK" "$PR_URL" "$WEEKLY_JSON"

echo "Fix pass complete for ${RUN_WEEK}"
