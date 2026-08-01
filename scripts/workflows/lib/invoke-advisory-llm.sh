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

run_with_provider_credentials() {
  local provider="$1"
  shift
  local credential_runner
  credential_runner="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-with-provider-credentials.sh"
  if [[ -n "${ADVISORY_CANDIDATE_TIMEOUT_SECONDS:-}" ]]; then
    if [[ ! "$ADVISORY_CANDIDATE_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
      echo "::error::ADVISORY_CANDIDATE_TIMEOUT_SECONDS must be a positive integer" >&2
      return 2
    fi
    "$credential_runner" "$provider" timeout --kill-after=10s \
      "${ADVISORY_CANDIDATE_TIMEOUT_SECONDS}s" "$@"
    return
  fi
  "$credential_runner" "$provider" "$@"
}

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
    claude)
      run_with_provider_credentials claude \
        bash "$advisory_dir/run-advisory-claude.sh" "$prompt_file" "$out_file"
      ;;
    opencode-sol)
      export ADVISORY_PROVIDER_USED=opencode
      run_with_provider_credentials opencode env \
        OPENCODE_MODELS="${OPENCODE_SOL_MODEL:-openai/gpt-5.6-sol}" \
        OPENCODE_VARIANT=medium \
        node "$lib_dir/run-opencode.mjs" "$prompt_file" "$out_file" "${OPENCODE_OUTPUT_SCHEMA:-}"
      ;;
    opencode-kimi)
      export ADVISORY_PROVIDER_USED=opencode
      run_with_provider_credentials opencode env \
        OPENCODE_MODELS="${OPENCODE_KIMI_MODEL:-openrouter/moonshotai/kimi-k3@preset/consensus}" \
        node "$lib_dir/run-opencode.mjs" "$prompt_file" "$out_file" "${OPENCODE_OUTPUT_SCHEMA:-}"
      ;;
    opencode)
      if [[ "${OPENCODE_FIX_MODE:-false}" == "true" ]]; then
        run_with_provider_credentials opencode \
          bash "$lib_dir/run-opencode-fix.sh" "$prompt_file" "$out_file" "$repo_root"
      else
        run_with_provider_credentials opencode \
          node "$lib_dir/run-opencode.mjs" "$prompt_file" "$out_file" "${OPENCODE_OUTPUT_SCHEMA:-}"
      fi
      ;;
    cursor)
      if [[ "${OPENCODE_FIX_MODE:-false}" == "true" ]]; then
        run_with_provider_credentials cursor env \
          CURSOR_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-cursor-grok-4.5-medium}}}" \
          bash "$lib_dir/run-cursor-fix.sh" "$prompt_file" "$out_file" "$repo_root"
      else
        run_with_provider_credentials cursor env \
          CURSOR_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-cursor-grok-4.5-medium}}}" \
          node "$advisory_dir/run-advisory-cursor.mjs" "$prompt_file" "$out_file"
      fi
      ;;
    gemini)
      run_with_provider_credentials gemini env \
        GEMINI_ADVISORY_MODEL="${WEEKLY_REVIEW_MODEL:-${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}}" \
        python3 "$advisory_dir/run-advisory-gemini.py" "$prompt_file" "$out_file"
      ;;
    antigravity)
      local full_diff_bytes="${ADVISORY_FULL_DIFF_BYTES:-0}"
      echo "Antigravity: full_diff_bytes=${full_diff_bytes}" >&2
      if ! run_with_provider_credentials antigravity \
        python3 "$advisory_dir/run-advisory-antigravity.py" "$repo_root" "$workdir" "$out_file"; then
        echo "::warning::Antigravity advisory review failed; falling back to Gemini generateContent"
        export ADVISORY_PROVIDER_USED=gemini
        run_with_provider_credentials gemini env \
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
