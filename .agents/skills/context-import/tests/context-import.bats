#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  SKILL_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/context-import-test.XXXXXX")"
  REPO="$TEST_ROOT/repo"
  CURSOR_ROOT="$TEST_ROOT/.cursor/projects/workspace/agent-transcripts"
  DB="$TEST_ROOT/opencode.db"
  SESSION_UUID="44992845-9592-49a9-af19-3d1d441d1b2d"
  mkdir -p "$REPO" "$CURSOR_ROOT/$SESSION_UUID"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" config user.name test
  printf '%s\n' initial >"$REPO/import.txt"
  git -C "$REPO" add import.txt
  git -C "$REPO" commit -qm 'Initial import fixture'
  git -C "$REPO" checkout -qb issue-456-context-import

  cat >"$CURSOR_ROOT/$SESSION_UUID/$SESSION_UUID.jsonl" <<'JSONL'
{"role":"user","message":{"content":[{"type":"text","text":"Implement issue #456 import.txt"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"Decision: normalize JSONL. Bearer cursor-secret"},{"type":"tool_use","name":"Read","input":{"path":"import.txt"}}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"Verification passed"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"Neutral final implementation details"}]}}
{"type":"turn_ended","status":"success"}
JSONL

  sqlite3 "$DB" <<'SQL'
CREATE TABLE session (id TEXT PRIMARY KEY, title TEXT, directory TEXT);
CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT);
CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER, data TEXT);
INSERT INTO session VALUES ('ses_source', 'OpenCode source', '/tmp/repo');
INSERT INTO message VALUES ('m1', 'ses_source', 100, '{"role":"user"}');
INSERT INTO part VALUES ('p1', 'm1', 'ses_source', 100, '{"type":"text","text":"OpenCode request for issue #456"}');
INSERT INTO message VALUES ('m2', 'ses_source', 200, '{"role":"assistant"}');
INSERT INTO part VALUES ('p2', 'm2', 'ses_source', 200, '{"type":"text","text":"OpenCode verification passed"}');
SQL
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "Cursor adapter normalizes text messages and ignores tool-only events" {
  run "$SKILL_ROOT/scripts/adapters/cursor.sh" \
    --session-id "$SESSION_UUID" --cursor-root "$CURSOR_ROOT"

  [ "$status" -eq 0 ]
  [ "$(jq -s 'length' <<<"$output")" -eq 4 ]
  [ "$(jq -r -s '.[0].platform' <<<"$output")" = cursor ]
  [ "$(jq -r -s '.[0].role' <<<"$output")" = user ]
  [ "$(jq -r -s '.[1].text' <<<"$output")" = 'Decision: normalize JSONL. Bearer cursor-secret' ]
}

@test "OpenCode adapter isolates an exact session" {
  run "$SKILL_ROOT/scripts/adapters/opencode.sh" \
    --session-id ses_source --db "$DB"

  [ "$status" -eq 0 ]
  [ "$(jq -s 'length' <<<"$output")" -eq 2 ]
  [ "$(jq -r -s '.[0].platform' <<<"$output")" = opencode ]
  [ "$(jq -r -s '.[0].session_id' <<<"$output")" = ses_source ]
}

@test "context-import creates a bounded packet and persistent receipt" {
  run "$SKILL_ROOT/scripts/context-import.sh" \
    --source cursor --session-id "$SESSION_UUID" \
    --cursor-root "$CURSOR_ROOT" --repo "$REPO" \
    --output-dir "$TEST_ROOT/output" --max-bytes 20000

  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.source' <<<"$output")" = cursor ]
  packet=$(jq -r '.packet_file' <<<"$output")
  receipt=$(jq -r '.receipt_file' <<<"$output")
  grep -q 'Implement issue #456' "$packet"
  grep -q 'Neutral final implementation details' "$packet"
  grep -q 'Bearer \[REDACTED\]' "$packet"
  [ -f "$receipt" ]
  [ "$(jq -r '.source' "$receipt")" = cursor ]
  [ "$(jq -r '.source_id' "$receipt")" = "$SESSION_UUID" ]
  run ! grep -q 'cursor-secret' "$packet"
}

@test "context-import rejects ambiguous or missing Cursor sessions" {
  run "$SKILL_ROOT/scripts/context-import.sh" \
    --source cursor --session-id missing-session \
    --cursor-root "$CURSOR_ROOT" --repo "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Cursor transcript not found"* ]]
}
