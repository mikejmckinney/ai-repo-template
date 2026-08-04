#!/usr/bin/env bash
# Archive a stopped OpenCode database generation before starting fresh.
set -euo pipefail

database="${OPENCODE_DB_PATH:-$HOME/.local/share/opencode/opencode.db}"
archive_dir=
apply=false
sqlite3_bin="${SQLITE3_BIN:-sqlite3}"
fuser_bin="${FUSER_BIN:-fuser}"

usage() {
  cat <<'EOF'
Usage: scripts/archive-opencode-database.sh [options]

Options:
  --apply                Create and verify the archive, then move the active generation.
  --database PATH        OpenCode database path.
  --archive-dir PATH     Exact archive destination.
  -h, --help             Show this help.

Without --apply, the command is a side-effect-free dry run.
EOF
}

fail() {
  printf 'archive-opencode-database: %s\n' "$*" >&2
  exit 1
}

file_size() {
  local path="$1"
  if [[ -f "$path" ]]; then
    stat -c %s "$path"
  else
    printf '0\n'
  fi
}

database_files() {
  local path
  for path in "$database" "$database-wal" "$database-shm"; do
    [[ -e "$path" ]] && printf '%s\n' "$path"
  done
}

database_in_use() {
  local files=()
  while IFS= read -r path; do files+=("$path"); done < <(database_files)
  [[ ${#files[@]} -gt 0 ]] || return 1
  "$fuser_bin" "${files[@]}" >/dev/null 2>&1
}

projection_counts() {
  local path="$1"
  "$sqlite3_bin" "$path" \
    'SELECT (SELECT count(*) FROM session), (SELECT count(*) FROM message), (SELECT count(*) FROM part);'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    --database)
      [[ -n "${2:-}" ]] || fail "$1 requires a value"
      database="$2"
      shift 2
      ;;
    --archive-dir)
      [[ -n "${2:-}" ]] || fail "$1 requires a value"
      archive_dir="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -f "$database" ]] || fail "database not found: $database"
[[ "$database" != *$'\n'* && "$database" != *'"'* ]] || fail "database path contains unsupported characters"
if [[ -z "$archive_dir" ]]; then
  archive_dir="$(dirname "$database")/archive/$(date -u +%Y%m%dT%H%M%SZ)"
fi
[[ "$archive_dir" != *$'\n'* && "$archive_dir" != *'"'* ]] || fail "archive path contains unsupported characters"

db_bytes="$(file_size "$database")"
wal_bytes="$(file_size "$database-wal")"
shm_bytes="$(file_size "$database-shm")"
printf 'mode=%s\n' "$([[ "$apply" == true ]] && printf apply || printf dry-run)"
printf 'database=%s\narchive_dir=%s\n' "$database" "$archive_dir"
printf 'db_bytes=%s\nwal_bytes=%s\nshm_bytes=%s\n' "$db_bytes" "$wal_bytes" "$shm_bytes"

[[ "$apply" == true ]] || exit 0
command -v "$sqlite3_bin" >/dev/null 2>&1 || fail "sqlite3 executable not found: $sqlite3_bin"
command -v "$fuser_bin" >/dev/null 2>&1 || fail "fuser executable not found: $fuser_bin"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"
[[ ! -e "$archive_dir" ]] || fail "archive destination already exists: $archive_dir"
if database_in_use; then
  fail "database files are in use; exit every OpenCode process before applying"
fi

required_bytes=$((db_bytes + wal_bytes + shm_bytes))
available_kb=
while read -r _ _ _ available _; do
  [[ "$available" =~ ^[0-9]+$ ]] && available_kb="$available"
done < <(df -Pk "$(dirname "$database")")
[[ "$available_kb" =~ ^[0-9]+$ ]] || fail "could not determine available disk space"
((available_kb * 1024 >= required_bytes)) || fail "insufficient disk space for a coherent backup"

mkdir -p "$archive_dir/raw"
backup="$archive_dir/restorable.db"
"$sqlite3_bin" "$database" ".backup \"$backup\""
[[ "$("$sqlite3_bin" "$backup" 'PRAGMA integrity_check;')" == ok ]] \
  || fail "backup integrity check failed; active database was not moved"

source_counts="$(projection_counts "$database")"
backup_counts="$(projection_counts "$backup")"
[[ "$source_counts" == "$backup_counts" ]] \
  || fail "backup projection counts differ; active database was not moved"
IFS='|' read -r session_count message_count part_count <<<"$backup_counts"
for count in "$session_count" "$message_count" "$part_count"; do
  [[ "$count" =~ ^[0-9]+$ ]] || fail "backup returned invalid projection counts"
done
backup_sha256="$(sha256sum "$backup" | cut -d' ' -f1)"

jq -n \
  --arg database "$database" \
  --arg archived_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg backup_sha256 "$backup_sha256" \
  --argjson db_bytes "$db_bytes" \
  --argjson wal_bytes "$wal_bytes" \
  --argjson shm_bytes "$shm_bytes" \
  --argjson session "$session_count" \
  --argjson message "$message_count" \
  --argjson part "$part_count" \
  '{database: $database, archived_at: $archived_at, backup_sha256: $backup_sha256,
    bytes: {database: $db_bytes, wal: $wal_bytes, shm: $shm_bytes},
    counts: {session: $session, message: $message, part: $part}}' \
  >"$archive_dir/manifest.json"

restore_on_error() {
  local status=$?
  local suffix source target
  for suffix in '' '-wal' '-shm'; do
    source="$archive_dir/raw/opencode.db$suffix"
    target="$database$suffix"
    if [[ -e "$source" && ! -e "$target" ]]; then
      mv "$source" "$target"
    fi
  done
  return "$status"
}
trap restore_on_error ERR

mv "$database" "$archive_dir/raw/opencode.db"
[[ ! -e "$database-wal" ]] || mv "$database-wal" "$archive_dir/raw/opencode.db-wal"
[[ ! -e "$database-shm" ]] || mv "$database-shm" "$archive_dir/raw/opencode.db-shm"
trap - ERR

printf 'archive_status=verified\n'
printf 'restorable_backup=%s\n' "$backup"
printf 'active_database_status=absent_until_next_opencode_start\n'
