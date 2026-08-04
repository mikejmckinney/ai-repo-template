#!/usr/bin/env bash

preserve_claude_session() {
  local session_id_file="$1" output_dir="$2"
  local lib_dir repo_root collector session_id
  if [[ ! -s "$session_id_file" ]]; then
    echo "::warning::Claude review failed without a persisted session identifier" >&2
    return
  fi

  session_id="$(<"$session_id_file")"
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$lib_dir/../../.." && pwd)"
  collector="$repo_root/scripts/workflows/advisory-review/collect-claude-session.py"
  if ! python3 "$collector" \
    --session-id "$session_id" \
    --output "$output_dir/${session_id}.jsonl" \
    --redact-env GITHUB_TOKEN \
    --redact-env GH_TOKEN \
    --redact-env OPENCODE_GITHUB_TOKEN \
    --redact-env ADVISORY_GITHUB_TOKEN \
    --redact-env CLAUDE_DIAGNOSTIC_OAUTH_TOKEN \
    --redact-env CLAUDE_CODE_OAUTH_TOKEN \
    --redact-env CURSOR_API_KEY \
    --redact-env OPENROUTER_API_KEY \
    --redact-env OPENCODE_AUTH_CONTENT; then
    echo "::warning::Failed to preserve Claude review session ${session_id}" >&2
  fi
}
