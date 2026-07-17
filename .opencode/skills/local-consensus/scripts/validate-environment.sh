#!/usr/bin/env bash

set -euo pipefail

missing=()
for command_name in opencode agent jq perl sqlite3; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'Missing required commands: %s\n' "${missing[*]}" >&2
  exit 1
fi

if ! opencode models openai | grep -qx 'openai/gpt-5.6-sol'; then
  printf 'OpenAI provider does not expose openai/gpt-5.6-sol\n' >&2
  exit 1
fi

if ! agent --list-models | grep -q '^cursor-grok-4.5-medium - '; then
  printf 'Cursor does not expose cursor-grok-4.5-medium\n' >&2
  exit 1
fi

jq -n '{status: "success", sol_model: "openai/gpt-5.6-sol", grok_model: "cursor-grok-4.5-medium"}'
