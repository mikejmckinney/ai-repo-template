#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  ARCHIVE_SCRIPT="$REPO_ROOT/scripts/archive-opencode-database.sh"
  DIAG_SCRIPT="$REPO_ROOT/scripts/diagnose-opencode-session.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/opencode-db-maintenance-test.XXXXXX")"
  DB="$TEST_ROOT/opencode.db"
  ARCHIVE="$TEST_ROOT/archive"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

create_database() {
  sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode = WAL;
CREATE TABLE session (id TEXT PRIMARY KEY, data TEXT NOT NULL);
CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, data TEXT NOT NULL);
CREATE TABLE part (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, message_id TEXT NOT NULL, data TEXT NOT NULL);
INSERT INTO session VALUES ('ses_test', '{}');
INSERT INTO message VALUES ('msg_test', 'ses_test', '{}');
INSERT INTO part VALUES ('prt_test', 'ses_test', 'msg_test', '{}');
SQL
}

@test "archive dry-run reports the plan without changing files" {
  create_database
  before="$(sha256sum "$DB")"

  run "$ARCHIVE_SCRIPT" --database "$DB" --archive-dir "$ARCHIVE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=dry-run"* ]]
  [ "$(sha256sum "$DB")" = "$before" ]
  [ ! -e "$ARCHIVE" ]
}

@test "archive apply refuses a database reported as active" {
  create_database

  run env FUSER_BIN=true "$ARCHIVE_SCRIPT" \
    --apply --database "$DB" --archive-dir "$ARCHIVE"

  [ "$status" -ne 0 ]
  [[ "$output" == *"database files are in use"* ]]
  [ -f "$DB" ]
  [ ! -e "$ARCHIVE" ]
}

@test "archive apply creates a verified backup and preserves the raw generation" {
  create_database

  run env FUSER_BIN=false "$ARCHIVE_SCRIPT" \
    --apply --database "$DB" --archive-dir "$ARCHIVE"

  [ "$status" -eq 0 ]
  [ ! -e "$DB" ]
  [ -f "$ARCHIVE/restorable.db" ]
  [ -f "$ARCHIVE/raw/opencode.db" ]
  [ -f "$ARCHIVE/manifest.json" ]
  [ "$(sqlite3 "$ARCHIVE/restorable.db" 'PRAGMA integrity_check;')" = ok ]
  [ "$(sqlite3 "$ARCHIVE/restorable.db" 'SELECT count(*) FROM session;')" -eq 1 ]
  [ "$(jq -r '.counts.session' "$ARCHIVE/manifest.json")" -eq 1 ]
  [ "$(jq -r '.backup_sha256 | length' "$ARCHIVE/manifest.json")" -eq 64 ]
}

@test "archive apply leaves the active database in place when backup verification fails" {
  printf 'not a sqlite database\n' >"$DB"

  run env FUSER_BIN=false "$ARCHIVE_SCRIPT" \
    --apply --database "$DB" --archive-dir "$ARCHIVE"

  [ "$status" -ne 0 ]
  [ -f "$DB" ]
  [ ! -e "$ARCHIVE/raw/opencode.db" ]
}

@test "archive apply preserves WAL and SHM sidecars when present" {
  create_database
  printf 'wal sentinel\n' >"$DB-wal"
  printf 'shm sentinel\n' >"$DB-shm"
  sqlite_stub="$TEST_ROOT/sqlite3"
  cat >"$sqlite_stub" <<'EOF'
#!/usr/bin/env bash
if [[ "$2" == .backup* ]]; then
  target="${2#*.backup \"}"
  target="${target%\"}"
  cp "$1" "$target"
  exit 0
fi
case "$2" in
  'PRAGMA integrity_check;') printf 'ok\n' ;;
  *'count(*) FROM session'*) printf '1|1|1\n' ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$sqlite_stub"

  run env FUSER_BIN=false SQLITE3_BIN="$sqlite_stub" "$ARCHIVE_SCRIPT" \
    --apply --database "$DB" --archive-dir "$ARCHIVE"

  [ "$status" -eq 0 ]
  [ "$(<"$ARCHIVE/raw/opencode.db-wal")" = "wal sentinel" ]
  [ "$(<"$ARCHIVE/raw/opencode.db-shm")" = "shm sentinel" ]
}

@test "diagnostic wrapper records bounded database and process memory evidence" {
  printf 'database bytes\n' >"$DB"
  printf 'wal bytes\n' >"$DB-wal"
  fake_opencode="$TEST_ROOT/opencode"
  cat >"$fake_opencode" <<'EOF'
#!/usr/bin/env bash
sleep 0.2
EOF
  chmod +x "$fake_opencode"
  diag="$TEST_ROOT/diag"

  run env OPENCODE_BIN="$fake_opencode" OPENCODE_DB_PATH="$DB" \
    OPENCODE_DIAG_DIR="$diag" OPENCODE_SAMPLE_INTERVAL=0.05 "$DIAG_SCRIPT"

  [ "$status" -eq 0 ]
  grep -q '^db_bytes=' "$diag/database.before"
  grep -q '^wal_bytes=' "$diag/database.before"
  grep -q '^peak_rss_kb=' "$diag/memory.summary"
  grep -q 'rss_kb=' "$diag/memory.samples"
  grep -q 'pss_anon_kb=' "$diag/memory.samples"
  [ ! -s "$diag/session-content" ]
}
