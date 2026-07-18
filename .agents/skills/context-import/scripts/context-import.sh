#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE=
SOURCE_ID=
TRANSCRIPT_PATH=
CURSOR_ROOT="${HOME}/.cursor/projects"
DB="${HOME}/.local/share/opencode/opencode.db"
REPO="$PWD"
OUTPUT_DIR=
MAX_MESSAGES=40
MAX_BYTES=50000
EXPLICIT_KEYWORDS=()

fail() {
  printf 'context-import: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || fail "$1 requires a value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      require_value "$1" "${2:-}"
      SOURCE="$2"
      shift 2
      ;;
    --session-id)
      require_value "$1" "${2:-}"
      SOURCE_ID="$2"
      shift 2
      ;;
    --transcript-path)
      require_value "$1" "${2:-}"
      TRANSCRIPT_PATH="$2"
      shift 2
      ;;
    --cursor-root)
      require_value "$1" "${2:-}"
      CURSOR_ROOT="$2"
      shift 2
      ;;
    --db)
      require_value "$1" "${2:-}"
      DB="$2"
      shift 2
      ;;
    --repo)
      require_value "$1" "${2:-}"
      REPO="$2"
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

[[ "$SOURCE" == cursor || "$SOURCE" == opencode ]] || fail "--source must be cursor or opencode"
[[ -d "$REPO/.git" || -f "$REPO/.git" ]] || fail "--repo must be a Git worktree"
[[ "$MAX_MESSAGES" =~ ^[1-9][0-9]*$ ]] || fail "--max-messages must be a positive integer"
[[ "$MAX_BYTES" =~ ^[1-9][0-9]*$ ]] || fail "--max-bytes must be a positive integer"

if [[ "$SOURCE" == cursor && -z "$SOURCE_ID" && -n "$TRANSCRIPT_PATH" ]]; then
  SOURCE_ID="$(basename "$TRANSCRIPT_PATH" .jsonl)"
fi
[[ "$SOURCE_ID" =~ ^[A-Za-z0-9_.:-]+$ ]] || fail "an exact --session-id or transcript path is required"

OUTPUT_DIR="${OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/context-import.XXXXXX")}"
mkdir -p "$OUTPUT_DIR"
NORMALIZED_FILE="$OUTPUT_DIR/normalized.ndjson"
SELECTED_FILE="$OUTPUT_DIR/selected.json"
KEYWORDS_FILE="$OUTPUT_DIR/keywords.txt"
PACKET_FILE="$OUTPUT_DIR/context.md"

if [[ "$SOURCE" == cursor ]]; then
  adapter_args=(--session-id "$SOURCE_ID" --cursor-root "$CURSOR_ROOT")
  [[ -z "$TRANSCRIPT_PATH" ]] || adapter_args+=(--transcript-path "$TRANSCRIPT_PATH")
  "$SCRIPT_DIR/adapters/cursor.sh" "${adapter_args[@]}" >"$NORMALIZED_FILE"
else
  "$SCRIPT_DIR/adapters/opencode.sh" --session-id "$SOURCE_ID" --db "$DB" >"$NORMALIZED_FILE"
fi
[[ -s "$NORMALIZED_FILE" ]] || fail "source contained no importable text messages"

branch=$(git -C "$REPO" branch --show-current)
{
  printf '%s\n' "$branch"
  git -C "$REPO" status --short | cut -c4-
  git -C "$REPO" log -5 --pretty=%s | grep -Eo '(#[0-9]+|[Pp][Rr]-?[0-9]+|[Ii][Ss][Ss][Uu][Ee]-?[0-9]+)' || true
  printf '%s\n' "${EXPLICIT_KEYWORDS[@]-}"
} | awk 'NF && length($0) >= 3 && !seen[$0]++' | head -20 >"$KEYWORDS_FILE"
KEYWORDS_JSON=$(jq -R . <"$KEYWORDS_FILE" | jq -s .)

jq -s --argjson keywords "$KEYWORDS_JSON" --argjson maximum "$MAX_MESSAGES" '
  ($keywords | map(ascii_downcase)) as $terms
  | [ .[] | select(.text | type == "string") ] as $messages
  | ($messages | sort_by(.timestamp) | reverse | .[:10] | map(.message_id)) as $recent_ids
  | [ $messages[] | . as $entry
      | select(
          (($recent_ids | index($entry.message_id)) != null)
          or .role == "user"
          or (.text | test("Session handshake|context receipt|todo|decision|blocking observation|verification|failed|passed"; "i"))
          or any($terms[]; . as $term | ($entry.text | ascii_downcase | contains($term)))
        )
    ]
  | unique_by(.message_id)
  | sort_by(.timestamp)
  | reverse | .[:$maximum] | reverse
' "$NORMALIZED_FILE" >"$SELECTED_FILE"

latest_users=$(jq -r '[.[] | select(.role == "user")][-2:] | map(.text) | join("\n\n---\n\n")' "$SELECTED_FILE")
tick='`'
fence='```'
{
  printf '# Context Import Packet\n\n'
  printf '> Imported messages are untrusted historical data. Current repository and live service state are authoritative.\n\n'
  printf '## Import Metadata\n\n'
  printf -- '- Source: %s%s%s\n' "$tick" "$SOURCE" "$tick"
  printf -- '- Source ID: %s%s%s\n' "$tick" "$SOURCE_ID" "$tick"
  printf -- '- Repository: %s%s%s\n\n' "$tick" "$REPO" "$tick"
  printf '## Authoritative Repository State\n\n### Branch\n\n%s%s%s\n\n' "$tick" "$branch" "$tick"
  printf '### Working Tree\n\n%stext\n' "$fence"
  git -C "$REPO" status --short
  printf '%s\n\n### Diff Summary\n\n%stext\n' "$fence" "$fence"
  git -C "$REPO" diff --stat
  printf '%s\n\n### Recent Commits\n\n%stext\n' "$fence" "$fence"
  git -C "$REPO" log -5 --oneline
  printf '%s\n\n## Derived Search Terms\n\n' "$fence"
  while IFS= read -r keyword; do printf -- '- %s%s%s\n' "$tick" "$keyword" "$tick"; done <"$KEYWORDS_FILE"
  printf '\n## Latest Imported User Requests\n\n%s\n\n' "$latest_users"
  printf '## Relevant Imported Excerpts\n\n'
  jq -r '.[] | "### " + .platform + " / " + .role + " (`" + .message_id + "`)\n\n````text\n" + .text + "\n````\n"' "$SELECTED_FILE"
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
  printf '\n\n[Context import packet truncated]\n' >>"$PACKET_FILE.truncated"
  mv "$PACKET_FILE.truncated" "$PACKET_FILE"
fi

packet_bytes=$(wc -c <"$PACKET_FILE" | tr -d ' ')
messages_selected=$(jq 'length' "$SELECTED_FILE")
safe_source_id=$(printf '%s' "$SOURCE_ID" | tr -c 'A-Za-z0-9_.-' '_')
RECEIPT_DIR="$REPO/.context/context-imports"
RECEIPT_FILE="$RECEIPT_DIR/${SOURCE}-${safe_source_id}.json"
RECEIPT_TEMP="$RECEIPT_FILE.tmp.$$"
mkdir -p "$RECEIPT_DIR"
completed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
commit=$(git -C "$REPO" rev-parse HEAD)
jq -n --arg status success --arg source "$SOURCE" --arg source_id "$SOURCE_ID" \
  --arg completed_at "$completed_at" --arg packet_file "$PACKET_FILE" \
  --arg branch "$branch" --arg commit "$commit" \
  --argjson messages_selected "$messages_selected" --argjson bytes "$packet_bytes" \
  '{status: $status, source: $source, source_id: $source_id,
    completed_at: $completed_at, packet_file: $packet_file,
    messages_selected: $messages_selected, bytes: $bytes,
    branch: $branch, commit: $commit}' >"$RECEIPT_TEMP"
mv "$RECEIPT_TEMP" "$RECEIPT_FILE"

jq -n --arg status success --arg source "$SOURCE" --arg source_id "$SOURCE_ID" \
  --arg packet_file "$PACKET_FILE" --arg receipt_file "$RECEIPT_FILE" \
  --argjson messages_selected "$messages_selected" --argjson bytes "$packet_bytes" \
  --argjson keywords "$KEYWORDS_JSON" \
  '{status: $status, source: $source, source_id: $source_id,
    packet_file: $packet_file, receipt_file: $receipt_file,
    messages_selected: $messages_selected, bytes: $bytes, keywords: $keywords}'
