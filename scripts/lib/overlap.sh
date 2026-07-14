#!/usr/bin/env bash
# Classify overlap between two newline-delimited path lists.

classify_overlap() {
  local a="$1" b="$2"
  if [[ ! -s "$a" || ! -s "$b" ]]; then
    echo "none"
    return 0
  fi
  if comm -12 <(sort -u "$a") <(sort -u "$b") | grep -q .; then
    echo "hard"
    return 0
  fi

  local a_dirs b_dirs
  a_dirs=$(awk 'index($0, "*")==0 && index($0, "?")==0 && index($0, "[")==0 && index($0, "/") {sub("/[^/]+$", ""); print}' "$a" | sort -u)
  b_dirs=$(awk 'index($0, "*")==0 && index($0, "?")==0 && index($0, "[")==0 && index($0, "/") {sub("/[^/]+$", ""); print}' "$b" | sort -u)
  if [[ -n "$a_dirs" && -n "$b_dirs" ]] \
    && comm -12 <(printf '%s\n' "$a_dirs") <(printf '%s\n' "$b_dirs") | grep -q .; then
    echo "soft"
    return 0
  fi
  echo "none"
}
