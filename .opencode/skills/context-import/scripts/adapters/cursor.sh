#!/usr/bin/env bash

set -euo pipefail

SESSION_ID=
TRANSCRIPT_PATH=
CURSOR_ROOT="${HOME}/.cursor/projects"

fail() {
  printf 'context-import cursor: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)
      SESSION_ID="${2:-}"
      shift 2
      ;;
    --transcript-path)
      TRANSCRIPT_PATH="${2:-}"
      shift 2
      ;;
    --cursor-root)
      CURSOR_ROOT="${2:-}"
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

if [[ -n "$TRANSCRIPT_PATH" ]]; then
  [[ -f "$TRANSCRIPT_PATH" ]] || fail "Cursor transcript not found: $TRANSCRIPT_PATH"
  [[ -n "$SESSION_ID" ]] || SESSION_ID="$(basename "$TRANSCRIPT_PATH" .jsonl)"
else
  [[ "$SESSION_ID" =~ ^[A-Za-z0-9-]+$ ]] || fail "--session-id or --transcript-path is required"
  shopt -s nullglob
  possible=(
    "$CURSOR_ROOT/$SESSION_ID/$SESSION_ID.jsonl"
    "$CURSOR_ROOT"/*/agent-transcripts/"$SESSION_ID/$SESSION_ID.jsonl"
  )
  shopt -u nullglob
  candidates=()
  for candidate in "${possible[@]}"; do
    [[ -f "$candidate" ]] && candidates+=("$candidate")
  done
  [[ ${#candidates[@]} -gt 0 ]] || fail "Cursor transcript not found for session $SESSION_ID"
  [[ ${#candidates[@]} -eq 1 ]] || fail "multiple Cursor transcripts found for session $SESSION_ID; use --transcript-path"
  TRANSCRIPT_PATH="${candidates[0]}"
fi

jq -sc --arg platform cursor --arg session_id "$SESSION_ID" '
  to_entries[]
  | select(.value.role == "user" or .value.role == "assistant")
  | [ .value.message.content[]?
      | select(.type == "text" and (.text | type == "string"))
      | .text
    ] as $parts
  | select($parts | length > 0)
  | {
      platform: $platform,
      session_id: $session_id,
      message_id: ($session_id + ":" + ((.key + 1) | tostring)),
      role: .value.role,
      timestamp: (.key + 1),
      text: ($parts | join("\n"))
    }
' "$TRANSCRIPT_PATH"
