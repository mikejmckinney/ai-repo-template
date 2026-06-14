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
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

python3 "$SCRIPT_DIR/validate-postmerge-retro-daily.py" "$DAILY_JSON"
RUN_DATE="$(jq -r .run_date "$DAILY_JSON")"
FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-daily-retro-findings.py" "$DAILY_JSON")"
if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "Zero findings; skipping fix PR"
  exit 0
fi

BRANCH="retro/fix-${RUN_DATE}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Cursor local mode can rewrite the running script on disk; re-exec from a temp copy.
if [[ -z "${POSTMERGE_RETRO_FIX_REEXEC:-}" ]]; then
  export POSTMERGE_RETRO_FIX_REEXEC=1
  cp "$SCRIPT_DIR/run-postmerge-retro-fix.sh" "$WORKDIR/fix-runner.sh"
  exec bash "$WORKDIR/fix-runner.sh" "$@"
fi

git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"

git fetch origin main
git checkout -B "$BRANCH" origin/main

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
  echo "Implement all findings on branch \`${BRANCH}\`. For Cursor/local mode, edit the repo directly."
  echo "For Gemini JSON mode, respond with JSON only (file_edits + commit_message)."
} >"$prompt_file"

has_cursor=0
has_gemini=0
[[ -n "${CURSOR_API_KEY:-}" ]] && has_cursor=1
[[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]] && has_gemini=1

strip_workflow_changes() {
  # CLAUDE_PAT / default GITHUB_TOKEN cannot push .github/workflows/** edits.
  local paths=()
  while IFS= read -r -d '' f; do
    paths+=("$f")
  done < <(git status --porcelain .github/workflows/ 2>/dev/null | awk '{print $2}' | tr '\n' '\0')
  if ((${#paths[@]} == 0)); then
    return 0
  fi
  echo "::notice::Stripping ${#paths[@]} .github/workflows/ change(s) from fix commit (token lacks workflows:write). Document skipped workflow edits in retro/fix-notes-${RUN_DATE}.md if needed." >&2
  for f in "${paths[@]}"; do
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      git checkout HEAD -- "$f"
    else
      rm -f "$f"
    fi
  done
}

pick_provider() {
  local want="${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}"
  if [[ "$want" == "antigravity" ]]; then
    echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; post-merge retro fix uses auto (cursor, else gemini)." >&2
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
    CURSOR_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}" \
      node "$ADVISORY_DIR/run-advisory-cursor.mjs" "$prompt_file" "$llm_raw"
    ;;
  gemini)
    GEMINI_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}" \
      python3 "$ADVISORY_DIR/run-advisory-gemini.py" "$prompt_file" "$llm_raw"
    fix_json="$WORKDIR/fix.json"
    python3 "$SCRIPT_DIR/extract-retro-fix-json.py" "$llm_raw" "$fix_json"
    jq --arg rd "$RUN_DATE" '. + {run_date: $rd}' "$fix_json" >"$WORKDIR/fix-with-date.json"
    python3 "$SCRIPT_DIR/apply-retro-fix-json.py" "$WORKDIR/fix-with-date.json" "$REPO_ROOT"
    ;;
esac

strip_workflow_changes

if ! git diff --quiet || ! git diff --cached --quiet; then
  commit_msg="fix: post-merge retro daily fixes for ${RUN_DATE}"
  if [[ -f "$REPO_ROOT/.artifacts/postmerge-retro/fix-commit-message.txt" ]]; then
    commit_msg="$(head -1 "$REPO_ROOT/.artifacts/postmerge-retro/fix-commit-message.txt")"
  fi
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
  cp "$REPO_ROOT/.github/templates/postmerge-retro-fix-pr.md" "$body_file"
  umbrella_num="$(gh search issues "postmerge-retro:daily:${RUN_DATE} is:issue" --repo "$REPO" --json number,url --limit 1 --jq '.[0].number // empty' 2>/dev/null || true)"
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
    -e "s|{{FIX_BRANCH}}|${BRANCH}|g" \
    -e "s|{{REPO}}|${REPO}|g" \
    "$body_file"
}

existing_pr="$(gh pr list -R "$REPO" --head "$BRANCH" --state open --json number --jq '.[0].number // empty')"
if [[ -n "$existing_pr" ]]; then
  echo "Open draft PR already exists: #${existing_pr}"
  PR_URL="$(gh pr view "$existing_pr" -R "$REPO" --json url --jq .url)"
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

bash "$SCRIPT_DIR/update-umbrella-fix-link.sh" "$RUN_DATE" "$PR_URL"

echo "Fix pass complete for ${RUN_DATE}"
