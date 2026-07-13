#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  SKILL_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/session-recovery-test.XXXXXX")"
  REPO="$TEST_ROOT/repo"
  DB="$TEST_ROOT/opencode.db"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" config user.name test
  printf '%s\n' initial >"$REPO/context.txt"
  git -C "$REPO" add context.txt
  git -C "$REPO" commit -qm 'Initial commit'
  git -C "$REPO" checkout -qb issue-321-session-recovery
  printf '%s\n' changed >>"$REPO/context.txt"

  sqlite3 "$DB" <<'SQL'
CREATE TABLE session (id TEXT PRIMARY KEY, title TEXT, directory TEXT);
CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT);
CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER, data TEXT);
INSERT INTO session VALUES ('ses_target', 'Recovery work', '/tmp/repo');
INSERT INTO session VALUES ('ses_other', 'Other work', '/tmp/repo');
INSERT INTO message VALUES ('m1', 'ses_target', 100, '{"role":"assistant"}');
INSERT INTO part VALUES ('p1', 'm1', 'ses_target', 100, '{"type":"text","text":"Session handshake v26\n| Field | Value |"}');
INSERT INTO message VALUES ('m2', 'ses_target', 200, '{"role":"user"}');
INSERT INTO part VALUES ('p2', 'm2', 'ses_target', 200, '{"type":"text","text":"Implement issue #321 recovery for context.txt"}');
INSERT INTO message VALUES ('m3', 'ses_target', 300, '{"role":"assistant"}');
INSERT INTO part VALUES ('p3', 'm3', 'ses_target', 300, '{"type":"text","text":"Decision: use SQLite. Authorization: Bearer secret-token-value"}');
INSERT INTO message VALUES ('m4', 'ses_target', 400, '{"role":"assistant"}');
INSERT INTO part VALUES ('p4', 'm4', 'ses_target', 400, '{"type":"text","text":"Verification passed for context.txt"}');
INSERT INTO message VALUES ('m5', 'ses_other', 500, '{"role":"user"}');
INSERT INTO part VALUES ('p5', 'm5', 'ses_other', 500, '{"type":"text","text":"UNRELATED SESSION SECRET"}');
INSERT INTO message VALUES ('m6', 'ses_target', 600, '{"role":"assistant"}');
INSERT INTO part VALUES ('p6', 'm6', 'ses_target', 600, '{"type":"text","text":{"synthetic":true}}');
SQL
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "recovery emits bounded JSON envelope and authoritative repository state" {
  run "$SKILL_ROOT/scripts/recover-context.sh" \
    --session-id ses_target --repo "$REPO" --db "$DB" \
    --output-dir "$TEST_ROOT/output" --max-messages 10 --max-bytes 20000

  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.session_id' <<<"$output")" = ses_target ]
  packet=$(jq -r '.packet_file' <<<"$output")
  grep -q 'issue-321-session-recovery' "$packet"
  grep -q 'context.txt' "$packet"
  [ "$(jq -r '.bytes' <<<"$output")" -le 20000 ]
  receipt=$(jq -r '.receipt_file' <<<"$output")
  [ "$receipt" = "$REPO/.context/session-recovery/ses_target.json" ]
  [ -f "$receipt" ]
  [ "$(jq -r '.status' "$receipt")" = success ]
  [ "$(jq -r '.session_id' "$receipt")" = ses_target ]
  [ "$(jq -r '.branch' "$receipt")" = issue-321-session-recovery ]
  [ "$(jq -r '.commit' "$receipt")" = "$(git -C "$REPO" rev-parse HEAD)" ]
  [ "$(jq -r '.completed_at' "$receipt")" != null ]
}

@test "recovery selects exact-session evidence and redacts secrets" {
  run "$SKILL_ROOT/scripts/recover-context.sh" \
    --session-id ses_target --repo "$REPO" --db "$DB" \
    --output-dir "$TEST_ROOT/output" --max-messages 10 --max-bytes 20000

  [ "$status" -eq 0 ]
  packet=$(jq -r '.packet_file' <<<"$output")
  grep -q 'Implement issue #321 recovery' "$packet"
  grep -q 'Verification passed' "$packet"
  grep -q 'Bearer \[REDACTED\]' "$packet"
  run ! grep -q 'secret-token-value\|UNRELATED SESSION SECRET' "$packet"
}

@test "recovery derives keywords from branch, changed files, and references" {
  run "$SKILL_ROOT/scripts/recover-context.sh" \
    --session-id ses_target --repo "$REPO" --db "$DB" \
    --output-dir "$TEST_ROOT/output" --keyword SQLite

  [ "$status" -eq 0 ]
  keywords=$(jq -r '.keywords | join(" ")' <<<"$output")
  [[ "$keywords" == *"issue-321-session-recovery"* ]]
  [[ "$keywords" == *"context.txt"* ]]
  [[ "$keywords" == *"SQLite"* ]]
}

@test "recovery fails for an unknown session" {
  run "$SKILL_ROOT/scripts/recover-context.sh" \
    --session-id ses_missing --repo "$REPO" --db "$DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"session not found"* ]]
}
