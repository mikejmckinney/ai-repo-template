#!/usr/bin/env bash

version_at_least() {
  local observed="$1" required="$2" index observed_part required_part
  local -a observed_parts required_parts

  IFS=. read -r -a observed_parts <<<"$observed"
  IFS=. read -r -a required_parts <<<"$required"
  for ((index = 0; index < ${#observed_parts[@]} || index < ${#required_parts[@]}; index++)); do
    observed_part="${observed_parts[index]:-0}"
    required_part="${required_parts[index]:-0}"
    observed_part="${observed_part%%[^0-9]*}"
    required_part="${required_part%%[^0-9]*}"
    observed_part="${observed_part:-0}"
    required_part="${required_part:-0}"
    if ((10#$observed_part > 10#$required_part)); then
      return 0
    fi
    if ((10#$observed_part < 10#$required_part)); then
      return 1
    fi
  done
}

extract_version() {
  local version
  version="$(grep -Eo '[0-9]+([.][0-9]+)+' <<<"$1" | head -n 1 || true)"
  printf '%s\n' "$version"
}
