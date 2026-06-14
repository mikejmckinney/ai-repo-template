#!/usr/bin/env bash
# Run weekly full-repo LLM review and write review.json.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
RUN_WEEK="${RUN_WEEK:-$(bash "$SCRIPT_DIR/resolve-run-week.sh")}"
OUT_JSON="${1:-}"
context_profile="${WEEKLY_REVIEW_CONTEXT_PROFILE:-full}"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

bash "$SCRIPT_DIR/collect-weekly-evidence.sh" "$WORKDIR"

if ! python3 "$LIB_DIR/prompt_helpers.py" select-context \
  --profile "$context_profile" \
  --changed-files "$WORKDIR/changed-files.txt" >"$WORKDIR/context-files.txt"; then
  echo "::error::select-context failed for profile ${context_profile}" >&2
  exit 1
fi
if [[ ! -s "$WORKDIR/context-files.txt" ]]; then
  echo "::error::select-context returned no files for profile ${context_profile}" >&2
  exit 1
fi
mapfile -t context_files <"$WORKDIR/context-files.txt"

context_file_count="${#context_files[@]}"
context_bytes=0
for rel in "${context_files[@]}"; do
  if [[ -f "$REPO_ROOT/$rel" ]]; then
    context_bytes=$((context_bytes + $(wc -c <"$REPO_ROOT/$rel" | tr -d ' ')))
  fi
done

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/weekly-repo-review.md"
  echo ""
  echo "---"
  echo ""
  echo "## Repo startup context (automation-supplied, catalog-driven ${context_profile} + path triggers)"
  echo ""
  echo "- Context profile: \`${context_profile}\`"
  echo "- Context files injected: \`${context_file_count}\`"
  echo "- Context bytes injected: \`${context_bytes}\`"
  echo ""
  for rel in "${context_files[@]}"; do
    echo "### ${rel}"
    echo ""
    if [[ -f "$REPO_ROOT/$rel" ]]; then
      cat "$REPO_ROOT/$rel"
    else
      echo "(missing on disk)"
    fi
    echo ""
  done
  echo "---"
  echo ""
  cat "$WORKDIR/repo-inventory.md"
  echo ""
  echo "---"
  echo ""
  echo "## Output instruction (automation-supplied)"
  echo ""
  echo "Respond with **JSON only** matching the required weekly review shape."
  echo "Run week: \`${RUN_WEEK}\`; scan date: \`${RUN_DATE}\`."
} >"$prompt_file"

has_cursor=0
has_gemini=0
[[ -n "${CURSOR_API_KEY:-}" ]] && has_cursor=1
[[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]] && has_gemini=1

pick_provider() {
  local want="${WEEKLY_REVIEW_PROVIDER:-${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}}"
  if [[ "$want" == "antigravity" ]]; then
    echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; weekly review uses auto (cursor, else gemini)." >&2
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
    *)
      echo "::error::Unknown WEEKLY_REVIEW_PROVIDER=${want} (use auto, cursor, or gemini)"
      exit 1
      ;;
  esac
}

PROVIDER="$(pick_provider)"
[[ -n "$PROVIDER" ]] || {
  echo "::error::No weekly review provider configured. Set CURSOR_API_KEY and/or GEMINI_API_KEY."
  exit 1
}

llm_raw="$WORKDIR/llm-output.txt"
case "$PROVIDER" in
  cursor)
    npm install --no-save @cursor/sdk >/dev/null 2>&1
    CURSOR_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}}" \
      node "$ADVISORY_DIR/run-advisory-cursor.mjs" "$prompt_file" "$llm_raw"
    ;;
  gemini)
    GEMINI_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}}" \
      python3 "$ADVISORY_DIR/run-advisory-gemini.py" "$prompt_file" "$llm_raw"
    ;;
esac

review_json="$WORKDIR/review.json"
python3 "$SCRIPT_DIR/extract-weekly-json.py" "$llm_raw" "$review_json"
python3 "$SCRIPT_DIR/validate-weekly-review.py" "$review_json"

if [[ -n "$OUT_JSON" ]]; then
  cp -f "$review_json" "$OUT_JSON"
fi

if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  artifact_dir="${GITHUB_WORKSPACE}/.artifacts/weekly-review/week-${RUN_WEEK}"
  mkdir -p "$artifact_dir"
  cp -f "$review_json" "$artifact_dir/review.json"
  cp -f "$llm_raw" "$artifact_dir/llm-output.txt" 2>/dev/null || true
fi

echo "Weekly review JSON written for ${RUN_WEEK} via ${PROVIDER}" >&2
