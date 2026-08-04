#!/usr/bin/env bash
# Bound one postmerge provider process so the caller can continue its fallback cascade.

run_postmerge_provider_with_timeout() {
  local timeout_seconds="$1" provider="$2" route="$3"
  shift 3

  local status
  if timeout --signal=TERM --kill-after=30s "${timeout_seconds}s" "$@"; then
    return 0
  else
    status=$?
  fi

  if [[ "$status" -eq 124 || "$status" -eq 137 ]]; then
    echo "::warning::Post-merge retro provider ${provider} ${route} timed out after ${timeout_seconds}s" >&2
  fi
  return "$status"
}
