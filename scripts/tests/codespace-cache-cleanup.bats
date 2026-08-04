#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLEANUP="$REPO_ROOT/scripts/cleanup-codespace-caches.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codespace-cache-cleanup.XXXXXX")"
  TEST_HOME="$TEST_ROOT/home"
  BIN_DIR="$TEST_ROOT/bin"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  mkdir -p "$TEST_HOME/.npm/_cacache" "$TEST_HOME/.npm/_npx" \
    "$TEST_HOME/.bun/install/cache" "$TEST_HOME/.cache/uv" \
    "$TEST_HOME/.cache/pip" "$TEST_HOME/.cache/go-build" \
    "$TEST_HOME/.local/share/opencode" "$TEST_HOME/.cursor/chats" "$BIN_DIR"
  printf 'keep\n' >"$TEST_HOME/.local/share/opencode/opencode.db"
  printf 'keep\n' >"$TEST_HOME/.cursor/chats/session"
  for path in \
    "$TEST_HOME/.npm/_cacache/package" \
    "$TEST_HOME/.npm/_npx/package" \
    "$TEST_HOME/.bun/install/cache/package" \
    "$TEST_HOME/.cache/uv/package" \
    "$TEST_HOME/.cache/pip/package" \
    "$TEST_HOME/.cache/go-build/package"; do
    printf 'cache data\n' >"$path"
  done

  cat >"$BIN_DIR/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >>"$COMMAND_LOG"
[[ "${FAIL_NPM:-false}" != true ]] || exit 23
if [[ "$*" == 'cache clean --force' ]]; then
  rm -rf "$HOME/.npm/_cacache"
else
  rm -rf "$HOME/.npm/_npx"
fi
EOF
  cat >"$BIN_DIR/uv" <<'EOF'
#!/usr/bin/env bash
printf 'uv %s\n' "$*" >>"$COMMAND_LOG"
rm -rf "$HOME/.cache/uv"
EOF
  cat >"$BIN_DIR/python3" <<'EOF'
#!/usr/bin/env bash
printf 'python3 %s\n' "$*" >>"$COMMAND_LOG"
rm -rf "$HOME/.cache/pip"
EOF
  cat >"$BIN_DIR/go" <<'EOF'
#!/usr/bin/env bash
printf 'go %s\n' "$*" >>"$COMMAND_LOG"
rm -rf "$HOME/.cache/go-build"
EOF
  cat >"$BIN_DIR/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ "${UV_ACTIVE:-false}" == true ]]
EOF
  chmod +x "$BIN_DIR"/*
}

teardown() {
  rm -rf "$TEST_ROOT"
}

run_cleanup() {
  run env HOME="$TEST_HOME" PATH="$BIN_DIR:/usr/bin:/bin" \
    COMMAND_LOG="$COMMAND_LOG" UV_CACHE_DIR="$TEST_HOME/.cache/uv" \
    PIP_CACHE_DIR="$TEST_HOME/.cache/pip" GOCACHE="$TEST_HOME/.cache/go-build" \
    UV_ACTIVE="${UV_ACTIVE:-false}" FAIL_NPM="${FAIL_NPM:-false}" \
    bash "$CLEANUP" "$@"
  printf 'status=%s\n%s\n' "$status" "$output" >&3
}

@test "dry-run reports cache sizes without changing files" {
  run_cleanup

  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=dry-run"* ]]
  [[ "$output" == *"cache=npm-content"* ]]
  [[ "$output" == *"cache=bun"* ]]
  [[ "$output" == *"re-run with --apply"* ]]
  [ -f "$TEST_HOME/.bun/install/cache/package" ]
  [ ! -e "$COMMAND_LOG" ]
}

@test "apply cleans each reproducible cache" {
  run_cleanup --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=apply"* ]]
  [ ! -e "$TEST_HOME/.npm/_cacache" ]
  [ ! -e "$TEST_HOME/.npm/_npx" ]
  [ ! -e "$TEST_HOME/.bun/install/cache" ]
  [ ! -e "$TEST_HOME/.cache/uv" ]
  [ ! -e "$TEST_HOME/.cache/pip" ]
  [ ! -e "$TEST_HOME/.cache/go-build" ]
  [ -f "$TEST_HOME/.local/share/opencode/opencode.db" ]
  [ -f "$TEST_HOME/.cursor/chats/session" ]
  grep -Fxq 'npm cache clean --force' "$COMMAND_LOG"
  grep -Fxq 'npm cache npx rm --force' "$COMMAND_LOG"
  grep -Fxq 'uv cache clean' "$COMMAND_LOG"
  grep -Fxq 'python3 -m pip cache purge' "$COMMAND_LOG"
  grep -Fxq 'go clean -cache' "$COMMAND_LOG"
}

@test "active uv runtime is skipped without blocking other cleanup" {
  UV_ACTIVE=true run_cleanup --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"cache=uv status=skipped reason=active-process"* ]]
  [ -f "$TEST_HOME/.cache/uv/package" ]
  grep -Fxq 'go clean -cache' "$COMMAND_LOG"
  ! grep -Fq 'uv cache clean' "$COMMAND_LOG"
}

@test "provider failure is reported after remaining cleanup runs" {
  FAIL_NPM=true run_cleanup --apply

  [ "$status" -ne 0 ]
  [[ "$output" == *"cache=npm-content status=failed"* ]]
  [[ "$output" == *"result=failed"* ]]
  grep -Fxq 'go clean -cache' "$COMMAND_LOG"
}

@test "unknown arguments fail without changing caches" {
  run_cleanup --all

  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown argument: --all"* ]]
  [ -f "$TEST_HOME/.bun/install/cache/package" ]
}
