#!/usr/bin/env bash
# scripts/workflows/lib/invoke-advisory-llm.sh — Cursor/Gemini advisory LLM dispatch.
#
# Usage:
#   source invoke-advisory-llm.sh
#   invoke_advisory_llm "$prompt_file" "$out_file" "$provider" "$advisory_dir" "$repo_root" "$workdir"
#
# Optional env for model overrides (first non-empty wins per provider):
#   CURSOR_ADVISORY_MODEL, POSTMERGE_RETRO_MODEL, WEEKLY_REVIEW_MODEL
#   GEMINI_ADVISORY_MODEL, POSTMERGE_RETRO_MODEL, WEEKLY_REVIEW_MODEL

invoke_advisory_llm() {
  local prompt_file="$1"
  local out_file="$2"
  local provider="$3"
  local advisory_dir="$4"
  local repo_root="$5"
  local workdir="$6"
  local lib_dir="${7:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

  case "$provider" in
    cursor)
      # shellcheck source=cursor-sdk-version.sh
      source "$lib_dir/cursor-sdk-version.sh"
      npm install --no-save "@cursor/sdk@${CURSOR_SDK_VERSION}" >/dev/null 2>&1
      CURSOR_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}}" \
        node "$advisory_dir/run-advisory-cursor.mjs" "$prompt_file" "$out_file"
      ;;
    gemini)
      GEMINI_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}}" \
        python3 "$advisory_dir/run-advisory-gemini.py" "$prompt_file" "$out_file"
      ;;
    antigravity)
      local full_diff_bytes="${ADVISORY_FULL_DIFF_BYTES:-0}"
      echo "Antigravity: full_diff_bytes=${full_diff_bytes}" >&2
      if ! python3 "$advisory_dir/run-advisory-antigravity.py" "$repo_root" "$workdir" "$out_file"; then
        echo "::warning::Antigravity advisory review failed; falling back to Gemini generateContent"
        GEMINI_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}}" \
          python3 "$advisory_dir/run-advisory-gemini.py" "$prompt_file" "$out_file"
      fi
      ;;
    *)
      echo "::error::invoke_advisory_llm: unsupported provider '${provider}'" >&2
      return 1
      ;;
  esac
}
