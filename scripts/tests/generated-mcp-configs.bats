#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GENERATOR="$REPO_ROOT/scripts/generate-mcp-configs.py"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/.config" "$TEST_ROOT/.opencode"
  cp "$REPO_ROOT/.config/mcp-inventory.json" "$TEST_ROOT/.config/mcp-inventory.json"
  cp "$REPO_ROOT/.mcp.json" "$TEST_ROOT/.mcp.json"
  cp "$REPO_ROOT/.opencode/opencode.json" "$TEST_ROOT/.opencode/opencode.json"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "MCP host configurations are current" {
  run python3 "$GENERATOR" --repo "$REPO_ROOT" --check

  [ "$status" -eq 0 ]
}

@test "MCP check reports stale host output" {
  jq '.mcpServers.github.url = "https://stale.invalid"' "$TEST_ROOT/.mcp.json" \
    >"$TEST_ROOT/stale.json"
  mv "$TEST_ROOT/stale.json" "$TEST_ROOT/.mcp.json"

  run python3 "$GENERATOR" --repo "$TEST_ROOT" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *".mcp.json"* ]]
  [[ "$output" == *"scripts/generate-mcp-configs.py"* ]]
}

@test "MCP generation preserves non-MCP OpenCode configuration" {
  before="$(jq -S 'del(.mcp)' "$TEST_ROOT/.opencode/opencode.json")"

  run python3 "$GENERATOR" --repo "$TEST_ROOT"

  [ "$status" -eq 0 ]
  [ "$before" = "$(jq -S 'del(.mcp)' "$TEST_ROOT/.opencode/opencode.json")" ]
  [ "$(jq -r '.mcp.netlify.timeout' "$TEST_ROOT/.opencode/opencode.json")" = "60000" ]
  [ "$(jq -r '.mcp.oci.enabled' "$TEST_ROOT/.opencode/opencode.json")" = "false" ]
  [ "$(jq -r '.mcp.github.headers.Authorization' "$TEST_ROOT/.opencode/opencode.json")" = 'Bearer {env:GH_PAT}' ]
  [ "$(jq -r '.mcpServers.github.headers.Authorization' "$TEST_ROOT/.mcp.json")" = 'Bearer ${GH_PAT}' ]
}
