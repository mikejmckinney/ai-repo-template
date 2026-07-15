#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: scripts/format.sh <--check|--write> <files...>" >&2
  exit 2
}

[[ $# -ge 2 ]] || usage
mode=$1
shift
[[ "$mode" == --check || "$mode" == --write ]] || usage

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shell_files=()
markdown_files=()

for file in "$@"; do
  [[ -f "$file" ]] || {
    echo "format: file not found: $file" >&2
    exit 1
  }
  case "$file" in
    *.sh) shell_files+=("$file") ;;
    *.md) markdown_files+=("$file") ;;
    *) echo "format: unsupported file type: $file" >&2; exit 1 ;;
  esac
done

if ((${#shell_files[@]})); then
  command -v shfmt >/dev/null 2>&1 || {
    echo "format: shfmt is required" >&2
    exit 1
  }
  if [[ "$mode" == --write ]]; then
    shfmt -w -i 2 -bn -ci "${shell_files[@]}"
  else
    shfmt -d -i 2 -bn -ci "${shell_files[@]}"
  fi
fi

if ((${#markdown_files[@]})); then
  markdown_args=(--yes markdownlint-cli2@0.17.2 --config "$repo_root/.markdownlint-cli2.jsonc")
  [[ "$mode" == --write ]] && markdown_args+=(--fix)
  npx "${markdown_args[@]}" "${markdown_files[@]}"
fi
