#!/usr/bin/env bash
set -euo pipefail

prompt_file="${1:?usage: run-advisory-claude.sh <prompt-file> <output-file>}"
output_file="${2:?usage: run-advisory-claude.sh <prompt-file> <output-file>}"
claude_bin="${CLAUDE_BIN:-claude}"
requested_model="claude-opus-5"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
schema_file="${ADVISORY_OUTPUT_SCHEMA:-$repo_root/.github/schemas/advisory-review.schema.json}"
response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

command -v "$claude_bin" >/dev/null 2>&1 || {
  echo "::error::Claude Code is required for the Claude advisory candidate" >&2
  exit 1
}
[[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] || {
  echo "::error::CLAUDE_CODE_OAUTH_TOKEN is required for the Claude advisory candidate" >&2
  exit 1
}
[[ -f "$schema_file" ]] || {
  echo "::error::Claude advisory schema is missing: $schema_file" >&2
  exit 1
}
schema_json="$(jq -c . "$schema_file")"

if ! "$claude_bin" -p \
  --model "$requested_model" \
  --effort medium \
  --output-format json \
  --json-schema "$schema_json" \
  --safe-mode \
  --tools "" \
  --permission-mode dontAsk \
  --no-session-persistence \
  <"$prompt_file" >"$response_file"; then
  echo "::error::Claude advisory invocation failed" >&2
  exit 1
fi

if ! jq -e '.is_error != true and (.structured_output | type == "object")' \
  "$response_file" >/dev/null; then
  echo "::error::Claude advisory returned an error or omitted structured output" >&2
  exit 1
fi

observed_model="$(jq -r '
  (.modelUsage // {}) | keys | sort |
  if length > 0 then join(",") else empty end
' "$response_file")"
[[ -n "$observed_model" ]] || {
  echo "::error::Claude advisory omitted observed model usage" >&2
  exit 1
}

jq -c .structured_output "$response_file" >"$output_file"
if [[ -n "${ADVISORY_PROVIDER_METADATA_FILE:-}" ]]; then
  jq -n \
    --arg provider claude \
    --arg model "$observed_model" \
    --arg requested_model "$requested_model" \
    --arg observed_model "$observed_model" \
    '{provider: $provider, model: $model, requested_model: $requested_model, observed_model: $observed_model}' \
    >"$ADVISORY_PROVIDER_METADATA_FILE"
fi
