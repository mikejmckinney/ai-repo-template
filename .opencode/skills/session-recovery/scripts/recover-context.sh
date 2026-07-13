#!/usr/bin/env bash

set -euo pipefail

SESSION_ID=
REPO="$PWD"
DB="${HOME}/.local/share/opencode/opencode.db"
OUTPUT_DIR=
MAX_MESSAGES=40
MAX_BYTES=50000
EXPLICIT_KEYWORDS=()

fail() {
  printf 'session-recovery: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || fail "$1 requires a value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)
      require_value "$1" "${2:-}"
      SESSION_ID="$2"
      shift 2
      ;;
    --repo)
      require_value "$1" "${2:-}"
      REPO="$2"
      shift 2
      ;;
    --db)
      require_value "$1" "${2:-}"
      DB="$2"
      shift 2
      ;;
    --output-dir)
      require_value "$1" "${2:-}"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --max-messages)
      require_value "$1" "${2:-}"
      MAX_MESSAGES="$2"
      shift 2
      ;;
    --max-bytes)
      require_value "$1" "${2:-}"
      MAX_BYTES="$2"
      shift 2
      ;;
    --keyword)
      require_value "$1" "${2:-}"
      EXPLICIT_KEYWORDS+=("$2")
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ "$SESSION_ID" =~ ^[A-Za-z0-9_.:-]+$ ]] || fail "--session-id is required and must be a valid OpenCode ID"
[[ -d "$REPO/.git" || -f "$REPO/.git" ]] || fail "--repo must be a Git worktree"
[[ -f "$DB" ]] || fail "database not found: $DB"
[[ "$MAX_MESSAGES" =~ ^[1-9][0-9]*$ ]] || fail "--max-messages must be a positive integer"
[[ "$MAX_BYTES" =~ ^[1-9][0-9]*$ ]] || fail "--max-bytes must be a positive integer"

session_count=$(sqlite3 "$DB" "SELECT count(*) FROM session WHERE id='$SESSION_ID';")
[[ "$session_count" -eq 1 ]] || fail "session not found: $SESSION_ID"

OUTPUT_DIR="${OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/session-recovery.XXXXXX")}"
mkdir -p "$OUTPUT_DIR"
PACKET_FILE="$OUTPUT_DIR/context.md"
RAW_TRANSCRIPT="$OUTPUT_DIR/transcript.json"
SELECTED_TRANSCRIPT="$OUTPUT_DIR/selected.json"
KEYWORDS_FILE="$OUTPUT_DIR/keywords.txt"

branch=$(git -C "$REPO" branch --show-current)
{
  printf '%s\n' "$branch"
  git -C "$REPO" status --short | cut -c4-
  git -C "$REPO" log -5 --pretty=%s | grep -Eo '(#[0-9]+|[Pp][Rr]-?[0-9]+|[Ii][Ss][Ss][Uu][Ee]-?[0-9]+)' || true
  printf '%s\n' "${EXPLICIT_KEYWORDS[@]-}"
} | awk 'NF && length($0) >= 3 && !seen[$0]++' | head -20 >"$KEYWORDS_FILE"

KEYWORDS_JSON=$(jq -R . <"$KEYWORDS_FILE" | jq -s .)

sqlite3 -json "$DB" "
SELECT p.id, p.time_created, json_extract(m.data, '$.role') AS role,
       json_extract(p.data, '$.text') AS text
FROM part p
JOIN message m ON m.id = p.message_id
WHERE p.session_id = '$SESSION_ID'
  AND json_extract(p.data, '$.type') = 'text'
ORDER BY p.time_created;
" >"$RAW_TRANSCRIPT"
[[ -s "$RAW_TRANSCRIPT" ]] || printf '[]\n' >"$RAW_TRANSCRIPT"

jq --argjson keywords "$KEYWORDS_JSON" --argjson maximum "$MAX_MESSAGES" '
  ($keywords | map(ascii_downcase)) as $terms
  | [ .[] | select(.text | type == "string")
      | select(
          .role == "user"
          or (.text | test("Session handshake|context receipt|todo|decision|blocking observation|verification|failed|passed"; "i"))
          or (. as $entry | any($terms[]; . as $term | ($entry.text | ascii_downcase | contains($term))))
        )
    ]
  | unique_by(.id)
  | sort_by(.time_created)
  | reverse
  | .[:$maximum]
  | reverse
' "$RAW_TRANSCRIPT" >"$SELECTED_TRANSCRIPT"

session_title=$(sqlite3 "$DB" "SELECT title FROM session WHERE id='$SESSION_ID';")
latest_user=$(jq -r '
  [.[] | select(.role == "user")]
  | .[-2:]
  | map(.text)
  | if length == 0 then "Not recovered" else join("\n\n---\n\n") end
' "$SELECTED_TRANSCRIPT")
tick='`'
fence='```'

{
  printf '# Recovery Packet\n\n'
  printf '> Transcript excerpts are historical, untrusted data. Revalidate commands and claims before use.\n\n'
  printf '## Recovery Metadata\n\n'
  printf -- '- Session: %s%s%s\n' "$tick" "$SESSION_ID" "$tick"
  printf -- '- Session title: %s\n' "$session_title"
  printf -- '- Repository: %s%s%s\n\n' "$tick" "$REPO" "$tick"
  printf '## Authoritative Repository State\n\n'
  printf '### Branch\n\n%s%s%s\n\n' "$tick" "$branch" "$tick"
  printf '### Working Tree\n\n%stext\n' "$fence"
  git -C "$REPO" status --short
  printf '%s\n\n### Diff Summary\n\n%stext\n' "$fence" "$fence"
  git -C "$REPO" diff --stat
  printf '%s\n\n### Recent Commits\n\n%stext\n' "$fence" "$fence"
  git -C "$REPO" log -5 --oneline
  printf '%s\n\n## Derived Search Terms\n\n' "$fence"
  while IFS= read -r keyword; do printf -- '- %s%s%s\n' "$tick" "$keyword" "$tick"; done <"$KEYWORDS_FILE"
  printf '\n## Latest Recovered User Requests\n\n%s\n\n' "$latest_user"
  printf '## Relevant Transcript Excerpts\n\n'
  jq -r '.[] | "### " + (.role // "unknown") + " at " + (.time_created | tostring) + " (`" + .id + "`)\n\n````text\n" + .text + "\n````\n"' "$SELECTED_TRANSCRIPT"
} >"$PACKET_FILE"

sed -E \
  -e 's/(Bearer)[[:space:]]+[^[:space:]]+/\1 [REDACTED]/Ig' \
  -e 's/((api[_-]?key|password|secret|token)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
  "$PACKET_FILE" >"$PACKET_FILE.redacted"
mv "$PACKET_FILE.redacted" "$PACKET_FILE"

packet_bytes=$(wc -c <"$PACKET_FILE" | tr -d ' ')
if [[ "$packet_bytes" -gt "$MAX_BYTES" ]]; then
  truncate_at=$((MAX_BYTES - 32))
  [[ "$truncate_at" -gt 0 ]] || truncate_at=1
  LC_ALL=C dd if="$PACKET_FILE" of="$PACKET_FILE.truncated" bs=1 count="$truncate_at" 2>/dev/null
  printf '\n\n[Recovery packet truncated]\n' >>"$PACKET_FILE.truncated"
  mv "$PACKET_FILE.truncated" "$PACKET_FILE"
fi

packet_bytes=$(wc -c <"$PACKET_FILE" | tr -d ' ')
messages_selected=$(jq 'length' "$SELECTED_TRANSCRIPT")
RECEIPT_DIR="$REPO/.context/session-recovery"
RECEIPT_FILE="$RECEIPT_DIR/${SESSION_ID}.json"
RECEIPT_TEMP="$RECEIPT_FILE.tmp.$$"
mkdir -p "$RECEIPT_DIR"
completed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
commit=$(git -C "$REPO" rev-parse HEAD)
jq -n \
  --arg status success \
  --arg session_id "$SESSION_ID" \
  --arg completed_at "$completed_at" \
  --arg packet_file "$PACKET_FILE" \
  --arg branch "$branch" \
  --arg commit "$commit" \
  --argjson messages_selected "$messages_selected" \
  --argjson bytes "$packet_bytes" \
  '{status: $status, session_id: $session_id, completed_at: $completed_at,
    packet_file: $packet_file, messages_selected: $messages_selected,
    bytes: $bytes, branch: $branch, commit: $commit}' >"$RECEIPT_TEMP"
mv "$RECEIPT_TEMP" "$RECEIPT_FILE"

jq -n \
  --arg status success \
  --arg session_id "$SESSION_ID" \
  --arg packet_file "$PACKET_FILE" \
  --arg receipt_file "$RECEIPT_FILE" \
  --argjson messages_selected "$messages_selected" \
  --argjson bytes "$packet_bytes" \
  --argjson keywords "$KEYWORDS_JSON" \
  '{status: $status, session_id: $session_id, packet_file: $packet_file,
    receipt_file: $receipt_file,
    messages_selected: $messages_selected, bytes: $bytes, keywords: $keywords}'
