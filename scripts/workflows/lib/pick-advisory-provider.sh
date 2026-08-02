#!/usr/bin/env bash
# scripts/workflows/lib/pick-advisory-provider.sh — shared provider routing.
#
# Usage:
#   source pick-advisory-provider.sh
#   PROVIDER="$(pick_advisory_provider MODE)"
#
# MODE:
#   advisory      — Claude / model-specific OpenCode / Cursor cascade
#   retro         — post-merge retro scan (POSTMERGE_RETRO_PROVIDER cascade)
#   retro-fix     — fix pass (no antigravity)
#   weekly-scan   — weekly scan (WEEKLY_REVIEW_PROVIDER cascade)
#   weekly-fix    — weekly fix (no antigravity)

init_advisory_provider_credentials() {
  has_claude=0
  has_opencode=0
  has_opencode_sol=0
  has_opencode_kimi=0
  has_cursor=0
  has_gemini=0
  local claude_bin="${CLAUDE_BIN:-claude}"
  local opencode_bin="${OPENCODE_BIN:-opencode}"
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=opencode-oauth.sh
  source "$lib_dir/opencode-oauth.sh"
  configure_opencode_oauth
  if command -v "$claude_bin" >/dev/null 2>&1 \
    && { [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] || [[ "${CLAUDE_OAUTH_AVAILABLE:-false}" == true ]]; }; then
    has_claude=1
  fi
  if command -v "$opencode_bin" >/dev/null 2>&1 \
    && [[ -n "${OPENCODE_GITHUB_TOKEN:-}" ]]; then
    [[ "${OPENCODE_SOL_AVAILABLE:-false}" == "true" ]] && has_opencode_sol=1
    [[ -n "${OPENROUTER_API_KEY:-}" ]] && has_opencode_kimi=1
  fi
  # Preserve the existing explicit/shared OpenCode contract, which includes Kimi fallback.
  has_opencode="$has_opencode_kimi"
  [[ -n "${CURSOR_API_KEY:-}" ]] && has_cursor=1
  [[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]] && has_gemini=1
  return 0
}

advisory_candidate_provider() {
  case "$1" in
    opencode-sol | opencode-kimi) printf '%s\n' opencode ;;
    claude | opencode | cursor) printf '%s\n' "$1" ;;
    *)
      echo "::error::unknown advisory candidate '$1'" >&2
      return 1
      ;;
  esac
}

list_advisory_providers() {
  local mode="${1:-advisory}"
  local want=""

  case "$mode" in
    advisory)
      want="${ADVISORY_REVIEW_PROVIDER:-auto}"
      ;;
    retro | retro-fix)
      want="${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}"
      ;;
    weekly-scan | weekly-fix)
      want="${WEEKLY_REVIEW_PROVIDER:-${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}}"
      ;;
    *)
      echo "::error::list_advisory_providers: unknown mode '${mode}'" >&2
      return 1
      ;;
  esac

  if [[ "$want" == "antigravity" ]]; then
    if [[ "$mode" == "weekly-scan" ]]; then
      printf '%s\n' antigravity
      return 0
    fi
    if [[ "$mode" == "advisory" ]]; then
      echo "::error::unsupported provider 'antigravity' for advisory" >&2
      return 1
    fi
    echo "::notice::Antigravity is scan-only; ${mode} uses the automatic provider cascade." >&2
    want=auto
  fi
  if [[ "$want" == "claude" && ("$mode" == "retro-fix" || "$mode" == "weekly-fix") ]]; then
    echo "::notice::Claude is analysis-only; ${mode} uses the automatic provider cascade." >&2
    want=auto
  fi

  if [[ "$want" != "auto" ]]; then
    case "$want" in
      claude | opencode | cursor)
        if [[ ("$mode" == "advisory" || "$mode" == "retro" || "$mode" == "weekly-scan") && "$want" == "claude" && -z "${OPENCODE_GITHUB_TOKEN:-}" ]]; then
          echo "::error::provider '${want}' requires OPENCODE_GITHUB_TOKEN for read-only GitHub retrieval" >&2
          return 1
        fi
        if [[ "$mode" == "advisory" && -z "${OPENCODE_GITHUB_TOKEN:-}" ]]; then
          echo "::error::provider '${want}' requires OPENCODE_GITHUB_TOKEN for advisory retrieval" >&2
          return 1
        fi
        printf '%s\n' "$want"
        ;;
      gemini)
        if [[ "$mode" == "advisory" ]]; then
          echo "::error::unsupported provider 'gemini' for advisory" >&2
          return 1
        fi
        printf '%s\n' "$want"
        ;;
      *)
        echo "::error::unsupported provider '${want}' for ${mode}" >&2
        return 1
        ;;
    esac
    return 0
  fi

  if [[ "$mode" == "advisory" ]]; then
    [[ "$has_claude" -eq 1 && -n "${OPENCODE_GITHUB_TOKEN:-}" ]] && printf '%s\n' claude
    [[ "$has_opencode_sol" -eq 1 ]] && printf '%s\n' opencode-sol
    [[ "$has_cursor" -eq 1 && -n "${OPENCODE_GITHUB_TOKEN:-}" ]] && printf '%s\n' cursor
    [[ "$has_opencode_kimi" -eq 1 ]] && printf '%s\n' opencode-kimi
    return 0
  fi

  if [[ "$mode" == "retro" || "$mode" == "weekly-scan" ]]; then
    [[ "$has_claude" -eq 1 && -n "${OPENCODE_GITHUB_TOKEN:-}" ]] && printf '%s\n' claude
  fi

  [[ "$has_opencode" -eq 1 ]] && printf '%s\n' opencode
  [[ "$has_cursor" -eq 1 ]] && printf '%s\n' cursor
  if [[ "$mode" == "weekly-scan" &&
    "${antigravity_enabled:-false}" == "true" && "$has_gemini" -eq 1 ]]; then
    printf '%s\n' antigravity
  fi
  [[ "$has_gemini" -eq 1 ]] && printf '%s\n' gemini
}

pick_advisory_provider() {
  local mode="${1:-advisory}"
  local want=""

  case "$mode" in
    advisory)
      want="${ADVISORY_REVIEW_PROVIDER:-auto}"
      ;;
    retro)
      want="${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}"
      if [[ "$want" == "antigravity" ]]; then
        echo "::notice::Antigravity is weekly-scan-only; post-merge retro uses auto (opencode, else cursor, else gemini)." >&2
        want=auto
      fi
      ;;
    retro-fix)
      want="${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}"
      if [[ "$want" == "antigravity" ]]; then
        echo "::notice::Antigravity is weekly-scan-only; post-merge retro fix uses auto (opencode, else cursor, else gemini)." >&2
        want=auto
      fi
      ;;
    weekly-scan)
      want="${WEEKLY_REVIEW_PROVIDER:-${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}}"
      ;;
    weekly-fix)
      want="${WEEKLY_REVIEW_PROVIDER:-${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}}"
      if [[ "$want" == "antigravity" ]]; then
        echo "::notice::Antigravity is weekly-scan-only; weekly fix uses auto (opencode, else cursor, else gemini)." >&2
        want=auto
      fi
      ;;
    *)
      echo "::error::pick_advisory_provider: unknown mode '${mode}'" >&2
      return 1
      ;;
  esac

  if [[ "$want" == "claude" && ("$mode" == "retro-fix" || "$mode" == "weekly-fix") ]]; then
    echo "::notice::Claude is analysis-only; ${mode} uses auto (opencode, else cursor, else gemini)." >&2
    want=auto
  fi

  case "$want" in
    claude)
      echo claude
      ;;
    opencode)
      echo opencode
      ;;
    cursor)
      echo cursor
      ;;
    antigravity)
      if [[ "$mode" != "weekly-scan" ]]; then
        echo "::error::antigravity is only valid for weekly-scan mode" >&2
        return 1
      fi
      echo antigravity
      ;;
    gemini)
      if [[ "$mode" == "advisory" ]]; then
        echo "::error::unsupported provider 'gemini' for advisory" >&2
        return 1
      fi
      echo gemini
      ;;
    auto)
      if [[ "$mode" == "advisory" ]]; then
        local candidate
        candidate="$(list_advisory_providers advisory | head -1)"
        if [[ -z "$candidate" ]]; then
          echo "::error::no advisory review provider configured" >&2
          return 1
        fi
        advisory_candidate_provider "$candidate"
        return
      fi
      if [[ ("$mode" == "retro" || "$mode" == "weekly-scan") && "$has_claude" -eq 1 && -n "${OPENCODE_GITHUB_TOKEN:-}" ]]; then
        echo claude
      elif [[ "$has_opencode" -eq 1 ]]; then
        echo opencode
      elif [[ "$has_cursor" -eq 1 ]]; then
        echo cursor
      elif [[ "$mode" == "weekly-scan" &&
        "${antigravity_enabled:-false}" == "true" && "$has_gemini" -eq 1 ]]; then
        echo antigravity
      elif [[ "$has_gemini" -eq 1 ]]; then
        echo gemini
      else
        echo ""
      fi
      ;;
    *)
      echo "::error::unsupported provider '${want}' for ${mode} (use auto, claude, opencode, cursor, antigravity, or gemini)" >&2
      return 1
      ;;
  esac
}
