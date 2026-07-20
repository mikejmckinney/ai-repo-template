#!/usr/bin/env bash
# scripts/workflows/lib/invoke-advisory-llm.sh — shared advisory LLM dispatch.
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
  export ADVISORY_PROVIDER_USED="$provider"

  case "$provider" in
    opencode)
      if [[ "${OPENCODE_FIX_MODE:-false}" == "true" ]]; then
        bash "$lib_dir/run-opencode-fix.sh" "$prompt_file" "$out_file" "$repo_root"
      else
        env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
          node "$lib_dir/run-opencode.mjs" "$prompt_file" "$out_file" "${OPENCODE_OUTPUT_SCHEMA:-}"
      fi
      ;;
    cursor)
      # shellcheck source=cursor-sdk-version.sh
      source "$lib_dir/cursor-sdk-version.sh"
      npm install --no-save "@cursor/sdk@${CURSOR_SDK_VERSION}" >/dev/null 2>&1
      CURSOR_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-cursor-grok-4.5-medium}}}" \
        env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
        node "$advisory_dir/run-advisory-cursor.mjs" "$prompt_file" "$out_file"
      ;;
    gemini)
      GEMINI_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}}" \
        env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
        python3 "$advisory_dir/run-advisory-gemini.py" "$prompt_file" "$out_file"
      ;;
    antigravity)
      local full_diff_bytes="${ADVISORY_FULL_DIFF_BYTES:-0}"
      echo "Antigravity: full_diff_bytes=${full_diff_bytes}" >&2
      if ! env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
        python3 "$advisory_dir/run-advisory-antigravity.py" "$repo_root" "$workdir" "$out_file"; then
        echo "::warning::Antigravity advisory review failed; falling back to Gemini generateContent"
        export ADVISORY_PROVIDER_USED=gemini
        GEMINI_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}}" \
          env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
          python3 "$advisory_dir/run-advisory-gemini.py" "$prompt_file" "$out_file"
      fi
      ;;
    *)
      echo "::error::invoke_advisory_llm: unsupported provider '${provider}'" >&2
      return 1
      ;;
  esac
}
