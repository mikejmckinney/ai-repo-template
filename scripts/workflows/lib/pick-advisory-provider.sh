#!/usr/bin/env bash
# scripts/workflows/lib/pick-advisory-provider.sh — shared provider routing.
#
# Usage:
#   source pick-advisory-provider.sh
#   PROVIDER="$(pick_advisory_provider MODE)"
#
# MODE:
#   advisory      — cursor / opencode / antigravity / gemini (ADVISORY_REVIEW_PROVIDER)
#   retro         — post-merge retro scan (POSTMERGE_RETRO_PROVIDER cascade)
#   retro-fix     — fix pass (no antigravity)
#   weekly-scan   — weekly scan (WEEKLY_REVIEW_PROVIDER cascade)
#   weekly-fix    — weekly fix (no antigravity)

init_advisory_provider_credentials() {
  has_opencode=0
  has_cursor=0
  has_gemini=0
  local opencode_bin="${OPENCODE_BIN:-opencode}"
  if command -v "$opencode_bin" >/dev/null 2>&1 \
    && [[ -n "${OPENROUTER_API_KEY:-}" ]] \
    && [[ -n "${OPENCODE_GITHUB_TOKEN:-}" ]]; then
    has_opencode=1
  fi
  [[ -n "${CURSOR_API_KEY:-}" ]] && has_cursor=1
  [[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]] && has_gemini=1
  return 0
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

  if [[ "$want" != "auto" && "$want" != "antigravity" ]]; then
    printf '%s\n' "$want"
    return 0
  fi

  [[ "$has_cursor" -eq 1 ]] && printf '%s\n' cursor
  [[ "$has_opencode" -eq 1 ]] && printf '%s\n' opencode
  if [[ ("$mode" == "advisory" || "$mode" == "weekly-scan") &&
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
        echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; post-merge retro uses auto (cursor, else gemini)." >&2
        want=auto
      fi
      ;;
    retro-fix)
      want="${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}"
      if [[ "$want" == "antigravity" ]]; then
        echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; post-merge retro fix uses auto (cursor, else gemini)." >&2
        want=auto
      fi
      ;;
    weekly-scan)
      want="${WEEKLY_REVIEW_PROVIDER:-${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}}"
      ;;
    weekly-fix)
      want="${WEEKLY_REVIEW_PROVIDER:-${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}}"
      if [[ "$want" == "antigravity" ]]; then
        echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; weekly fix uses auto (cursor, else gemini)." >&2
        want=auto
      fi
      ;;
    *)
      echo "::error::pick_advisory_provider: unknown mode '${mode}'" >&2
      return 1
      ;;
  esac

  case "$want" in
    opencode)
      echo opencode
      ;;
    cursor)
      echo cursor
      ;;
    antigravity)
      if [[ "$mode" != "advisory" && "$mode" != "weekly-scan" ]]; then
        echo "::error::antigravity is only valid for advisory and weekly-scan modes" >&2
        return 1
      fi
      echo antigravity
      ;;
    gemini)
      echo gemini
      ;;
    auto)
      if [[ "$has_cursor" -eq 1 ]]; then
        echo cursor
      elif [[ "$has_opencode" -eq 1 ]]; then
        echo opencode
      elif [[ ("$mode" == "advisory" || "$mode" == "weekly-scan") &&
        "${antigravity_enabled:-false}" == "true" && "$has_gemini" -eq 1 ]]; then
        echo antigravity
      elif [[ "$has_gemini" -eq 1 ]]; then
        echo gemini
      else
        echo ""
      fi
      ;;
    *)
      if [[ "$mode" == "advisory" ]]; then
        echo "::error::Unknown ADVISORY_REVIEW_PROVIDER=${want} (use auto, opencode, cursor, antigravity, or gemini)" >&2
        return 1
      fi
      echo "$want"
      ;;
  esac
}
