#!/usr/bin/env bash
set -euo pipefail

prompt_file="${1:?usage: run-claude-review.sh <prompt-file> <output-file>}"
output_file="${2:?usage: run-claude-review.sh <prompt-file> <output-file>}"
claude_bin="${CLAUDE_BIN:-claude}"
requested_model="claude-opus-5"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
schema_file="${CLAUDE_REVIEW_SCHEMA:?CLAUDE_REVIEW_SCHEMA is required}"
response_file="$(mktemp)"
mcp_config="$(mktemp)"
session_id="${CLAUDE_REVIEW_SESSION_ID:-$(python3 -c 'import uuid; print(uuid.uuid4())')}"
trap 'rm -f "$response_file" "$mcp_config"' EXIT

if [[ -n "${CLAUDE_REVIEW_SESSION_ID_FILE:-}" ]]; then
  printf '%s\n' "$session_id" >"$CLAUDE_REVIEW_SESSION_ID_FILE"
fi

command -v "$claude_bin" >/dev/null 2>&1 || {
  echo "::error::Claude Code is required for the Claude review candidate" >&2
  exit 1
}
[[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] || {
  echo "::error::CLAUDE_CODE_OAUTH_TOKEN is required for the Claude review candidate" >&2
  exit 1
}
[[ -n "${ADVISORY_GITHUB_TOKEN:-}" ]] || {
  echo "::error::ADVISORY_GITHUB_TOKEN is required for read-only GitHub retrieval" >&2
  exit 1
}
[[ -f "$schema_file" ]] || {
  echo "::error::Claude review schema is missing: $schema_file" >&2
  exit 1
}

schema_json="$(
  jq -c '
    if .["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    then .["$schema"] = "http://json-schema.org/draft-07/schema#"
    else .
    end
  ' "$schema_file"
)"
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
  --mcp-config "$mcp_config" \
  --strict-mcp-config \
  --tools "Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__*" \
  --allowedTools "Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__*" \
  --permission-mode dontAsk \
  --session-id "$session_id" \
  <"$prompt_file" >"$response_file"; then
  echo "::error::Claude review invocation failed" >&2
  exit 1
fi

if ! jq -e '.is_error != true and (.structured_output | type == "object")' \
  "$response_file" >/dev/null; then
  echo "::error::Claude review returned an error or omitted structured output" >&2
  exit 1
fi

if ! jq -e --arg model "$requested_model" '
  (.modelUsage | type == "object") and (.modelUsage | has($model))
' "$response_file" >/dev/null; then
  echo "::error::Claude review omitted observed model usage for ${requested_model}" >&2
  exit 1
fi

if [[ -n "${CLAUDE_RETRIEVAL_TRACE_FILE:-}" ]]; then
  python3 "$repo_root/scripts/workflows/lib/extract-claude-retrieval.py" \
    --session-id "$session_id" \
    --repo-root "$repo_root" \
    --output "$CLAUDE_RETRIEVAL_TRACE_FILE"
fi

jq -c .structured_output "$response_file" >"$output_file"
if [[ -n "${ADVISORY_PROVIDER_METADATA_FILE:-}" ]]; then
  jq -n \
    --arg provider claude \
    --arg model "$requested_model" \
    --arg requested_model "$requested_model" \
    --arg observed_model "$requested_model" \
    '{provider: $provider, model: $model, requested_model: $requested_model, observed_model: $observed_model}' \
    >"$ADVISORY_PROVIDER_METADATA_FILE"
fi
