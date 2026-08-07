#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  LOGGER="$REPO_ROOT/scripts/mcp-startup-logger.py"
  TEST_ROOT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "MCP startup logger preserves protocol stdout and redacts stderr" {
  fake_server="$TEST_ROOT/fake-server.sh"
  cat >"$fake_server" <<'EOF'
#!/usr/bin/env bash
printf '{"jsonrpc":"2.0","result":"ready"}\n'
printf 'startup failed with token %s\n' "$TEST_API_TOKEN" >&2
EOF
  chmod +x "$fake_server"

  run env MCP_STARTUP_LOG_DIR="$TEST_ROOT/logs" TEST_API_TOKEN='test-secret-value' \
    python3 "$LOGGER" test-server -- "$fake_server"

  [ "$status" -eq 0 ]
  [ "$output" = '{"jsonrpc":"2.0","result":"ready"}' ]
  [ "$(stat -c '%a' "$TEST_ROOT/logs")" = "700" ]
  [ "$(stat -c '%a' "$TEST_ROOT/logs/test-server.log")" = "600" ]
  run grep -F 'test-secret-value' "$TEST_ROOT/logs/test-server.log"
  [ "$status" -eq 1 ]
  run grep -F '[REDACTED:TEST_API_TOKEN]' "$TEST_ROOT/logs/test-server.log"
  [ "$status" -eq 0 ]
  for event in start stderr stderr_closed exit; do
    run grep -F '"event": "'"$event"'"' "$TEST_ROOT/logs/test-server.log"
    [ "$status" -eq 0 ]
  done
}

@test "MCP startup logger records exec failures without polluting stdout" {
  run -127 env MCP_STARTUP_LOG_DIR="$TEST_ROOT/logs" \
    python3 "$LOGGER" broken-server -- "$TEST_ROOT/missing-command"

  [ "$status" -eq 127 ]
  [ -z "$output" ]
  run grep -F 'failed to exec MCP server' "$TEST_ROOT/logs/broken-server.log"
  [ "$status" -eq 0 ]
  run grep -F '"event": "exec_error"' "$TEST_ROOT/logs/broken-server.log"
  [ "$status" -eq 0 ]
}
