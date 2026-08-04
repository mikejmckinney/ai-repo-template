#!/usr/bin/env bash

parse_positive_int() {
  local name="$1" default="$2" raw="${3:-}"
  if [[ -z "$raw" ]]; then
    echo "$default"
    return
  fi
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ $((10#$raw)) -gt 0 ]]; then
    echo "$((10#$raw))"
    return
  fi
  echo "::warning::Invalid ${name}=${raw}; using default ${default}" >&2
  echo "$default"
}
