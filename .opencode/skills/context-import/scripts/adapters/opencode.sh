#!/usr/bin/env bash

set -euo pipefail

SESSION_ID=
DB="${HOME}/.local/share/opencode/opencode.db"

fail() {
  printf 'context-import opencode: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)
      SESSION_ID="${2:-}"
      shift 2
      ;;
    --db)
      DB="${2:-}"
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ "$SESSION_ID" =~ ^[A-Za-z0-9_.:-]+$ ]] || fail "--session-id is required"
[[ -f "$DB" ]] || fail "database not found: $DB"
session_count=$(sqlite3 "$DB" "SELECT count(*) FROM session WHERE id='$SESSION_ID';")
[[ "$session_count" -eq 1 ]] || fail "OpenCode session not found: $SESSION_ID"

sqlite3 -json "$DB" "
SELECT p.id AS message_id, p.time_created AS timestamp,
       json_extract(m.data, '$.role') AS role,
       json_extract(p.data, '$.text') AS text
FROM part p
JOIN message m ON m.id = p.message_id
WHERE p.session_id = '$SESSION_ID'
  AND json_extract(p.data, '$.type') = 'text'
  AND json_type(p.data, '$.text') = 'text'
ORDER BY p.time_created;
" | jq -c --arg platform opencode --arg session_id "$SESSION_ID" \
  '.[] | . + {platform: $platform, session_id: $session_id}'
