#!/usr/bin/env bash
# scripts/workflows/lib/pick-advisory-provider.sh — shared provider routing.
#
# Usage:
#   source pick-advisory-provider.sh
#   PROVIDER="$(pick_advisory_provider MODE)"
#
# MODE:
#   advisory      — cursor / antigravity / gemini (ADVISORY_REVIEW_PROVIDER)
#   retro         — post-merge retro scan (POSTMERGE_RETRO_PROVIDER cascade)
#   retro-fix     — fix pass (no antigravity)
#   weekly-scan   — weekly scan (WEEKLY_REVIEW_PROVIDER cascade)
#   weekly-fix    — weekly fix (no antigravity)

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
      if [[ "$want" == "antigravity" ]]; then
        echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; weekly scan uses auto (cursor, else gemini)." >&2
        want=auto
      fi
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
    cursor)
      echo cursor
      ;;
    antigravity)
      if [[ "$mode" != "advisory" ]]; then
        echo "::error::antigravity is only valid for advisory mode" >&2
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
      elif [[ "$mode" == "advisory" && "${antigravity_enabled:-false}" == "true" && "$has_gemini" -eq 1 ]]; then
        echo antigravity
      elif [[ "$has_gemini" -eq 1 ]]; then
        echo gemini
      else
        echo ""
      fi
      ;;
    *)
      if [[ "$mode" == "advisory" ]]; then
        echo "::error::Unknown ADVISORY_REVIEW_PROVIDER=${want} (use auto, cursor, antigravity, or gemini)" >&2
        return 1
      fi
      echo "$want"
      ;;
  esac
}
