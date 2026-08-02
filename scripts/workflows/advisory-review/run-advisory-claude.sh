#!/usr/bin/env bash
set -euo pipefail

prompt_file="${1:?usage: run-advisory-claude.sh <prompt-file> <output-file>}"
output_file="${2:?usage: run-advisory-claude.sh <prompt-file> <output-file>}"
claude_bin="${CLAUDE_BIN:-claude}"
requested_model="claude-opus-5"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
schema_file="${ADVISORY_OUTPUT_SCHEMA:-$repo_root/.github/schemas/advisory-review.schema.json}"
response_file="$(mktemp)"
mcp_config="$(mktemp)"
session_id="${CLAUDE_ADVISORY_SESSION_ID:-$(python3 -c 'import uuid; print(uuid.uuid4())')}"
trap 'rm -f "$response_file" "$mcp_config"' EXIT

if [[ -n "${CLAUDE_ADVISORY_SESSION_ID_FILE:-}" ]]; then
  printf '%s\n' "$session_id" >"$CLAUDE_ADVISORY_SESSION_ID_FILE"
fi

command -v "$claude_bin" >/dev/null 2>&1 || {
  echo "::error::Claude Code is required for the Claude advisory candidate" >&2
  exit 1
}
[[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] || {
  echo "::error::CLAUDE_CODE_OAUTH_TOKEN is required for the Claude advisory candidate" >&2
  exit 1
}
[[ -n "${ADVISORY_GITHUB_TOKEN:-}" ]] || {
  echo "::error::ADVISORY_GITHUB_TOKEN is required for direct PR retrieval" >&2
  exit 1
}
[[ -f "$schema_file" ]] || {
  echo "::error::Claude advisory schema is missing: $schema_file" >&2
  exit 1
}
schema_json="$(jq -c . "$schema_file")"
cat >"$mcp_config" <<'EOF'
{
  "mcpServers": {
    "github_read": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${ADVISORY_GITHUB_TOKEN}",
        "X-MCP-Toolsets": "repos,issues,pull_requests,actions",
        "X-MCP-Readonly": "true",
        "X-MCP-Lockdown": "true"
      }
    }
  }
}
EOF

if ! "$claude_bin" -p \
  --model "$requested_model" \
  --effort medium \
  --output-format json \
  --json-schema "$schema_json" \
  --safe-mode \
  --mcp-config "$mcp_config" \
  --strict-mcp-config \
  --tools "Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__*" \
  --allowedTools "Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__*" \
  --permission-mode dontAsk \
  --session-id "$session_id" \
  <"$prompt_file" >"$response_file"; then
  echo "::error::Claude advisory invocation failed" >&2
  exit 1
fi

if ! jq -e '.is_error != true and (.structured_output | type == "object")' \
  "$response_file" >/dev/null; then
  echo "::error::Claude advisory returned an error or omitted structured output" >&2
  exit 1
fi

if ! jq -e --arg model "$requested_model" '
  (.modelUsage | type == "object") and (.modelUsage | has($model))
' "$response_file" >/dev/null; then
  echo "::error::Claude advisory omitted observed model usage for ${requested_model}" >&2
  exit 1
fi
observed_model="$requested_model"

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
