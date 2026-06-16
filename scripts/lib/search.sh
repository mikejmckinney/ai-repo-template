#!/usr/bin/env bash
# scripts/lib/search.sh — ripgrep with grep fallback (soft dependency on rg).
#
# Usage (after source):
#   search_fixed PATTERN [PATH...]
#   search_regex PATTERN [PATH...]

search_fixed() {
  if command -v rg >/dev/null 2>&1; then
    rg -F --no-heading -- "$@"
  else
    # shellcheck disable=SC2068
    grep -F -- "${@:1:1}" "${@:2}"
  fi
}

search_regex() {
  if command -v rg >/dev/null 2>&1; then
    rg --no-heading -- "$@"
  else
    # shellcheck disable=SC2068
    grep -E -- "${@:1:1}" "${@:2}"
  fi
}
