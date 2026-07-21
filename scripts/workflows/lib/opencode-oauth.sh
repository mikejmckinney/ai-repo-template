#!/usr/bin/env bash

OPENCODE_SOL_MODEL="openai/gpt-5.6-sol"
OPENCODE_KIMI_MODEL="openrouter/moonshotai/kimi-k3@preset/consensus"

configure_opencode_oauth() {
  local auth_content="${OPENCODE_AUTH_CONTENT:-}"
  local min_ttl_seconds="${OPENCODE_OAUTH_MIN_TTL_SECONDS:-0}"
  local expires now_ms remaining_seconds

  export OPENCODE_MODELS="$OPENCODE_KIMI_MODEL"
  [[ -n "$auth_content" ]] || return 0

  if [[ ! "$min_ttl_seconds" =~ ^[0-9]+$ ]]; then
    echo "::warning::Invalid OPENCODE_OAUTH_MIN_TTL_SECONDS; omitting Sol" >&2
    unset OPENCODE_AUTH_CONTENT
    return 0
  fi

  if ! jq -e '
    .openai.type == "oauth" and
    (.openai.access | type == "string" and length > 0) and
    .openai.refresh == "ci-refresh-disabled" and
    (.openai.expires | type == "number") and
    (.openai.accountId | type == "string" and length > 0)
  ' >/dev/null 2>&1 <<<"$auth_content"; then
    echo "::warning::OPENCODE_AUTH_CONTENT is invalid or refresh-enabled; omitting Sol" >&2
    unset OPENCODE_AUTH_CONTENT
    return 0
  fi

  expires="$(jq -r '.openai.expires | floor' <<<"$auth_content")"
  now_ms="$(($(date +%s) * 1000))"
  remaining_seconds="$(((expires - now_ms) / 1000))"
  if ((remaining_seconds < min_ttl_seconds)); then
    echo "::notice::OpenCode OAuth access has ${remaining_seconds}s remaining; Sol requires ${min_ttl_seconds}s and will be omitted" >&2
    unset OPENCODE_AUTH_CONTENT
    return 0
  fi

  export OPENCODE_MODELS="${OPENCODE_SOL_MODEL},${OPENCODE_KIMI_MODEL}"
  echo "::notice::OpenCode OAuth access accepted for Sol (${remaining_seconds}s remaining)" >&2
}
