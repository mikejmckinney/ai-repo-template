#!/usr/bin/env bash

set -Eeuo pipefail

server="${1:-}"
package="${2:-}"
shift 2 2>/dev/null || true

chrome="$(command -v google-chrome-for-testing || true)"
if [[ -z "$chrome" ]]; then
  printf 'error: Chrome for Testing is missing; run scripts/install-codespace-tools.sh --profile core\n' >&2
  exit 1
fi

case "$server" in
  playwright)
    exec npx -y "$package" --executable-path "$chrome" --headless "$@"
    ;;
  chrome-devtools)
    exec npx -y "$package" --executable-path "$chrome" --headless \
      --isolated --no-usage-statistics "$@"
    ;;
  *)
    printf 'error: unsupported browser MCP server: %s\n' "$server" >&2
    exit 1
    ;;
esac
