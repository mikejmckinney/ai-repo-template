#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GENERATOR="$REPO_ROOT/scripts/generate-agent-runtime.py"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/.github/agent-runtime"
  for file in base.json review.overlay.json fix.overlay.json review.json fix.json; do
    cp "$REPO_ROOT/.github/agent-runtime/$file" \
      "$TEST_ROOT/.github/agent-runtime/$file"
  done
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "runtime profiles are current" {
  run python3 "$GENERATOR" --repo "$REPO_ROOT" --check

  [ "$status" -eq 0 ]
}

@test "runtime profile check detects stale generated output" {
  jq '.agent.build.steps = 99' "$TEST_ROOT/.github/agent-runtime/review.json" \
    >"$TEST_ROOT/stale.json"
  mv "$TEST_ROOT/stale.json" "$TEST_ROOT/.github/agent-runtime/review.json"

  run python3 "$GENERATOR" --repo "$TEST_ROOT" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"review.json"* ]]
  [[ "$output" == *"scripts/generate-agent-runtime.py"* ]]
}

@test "runtime generation preserves direct security semantics" {
  run python3 "$GENERATOR" --repo "$TEST_ROOT"
  [ "$status" -eq 0 ]

  [ "$(jq -r '.permission["*"]' "$TEST_ROOT/.github/agent-runtime/review.json")" = "deny" ]
  [ "$(jq -r '.permission.edit' "$TEST_ROOT/.github/agent-runtime/review.json")" = "deny" ]
  [ "$(jq -r '.permission.edit' "$TEST_ROOT/.github/agent-runtime/fix.json")" = "allow" ]
  [ "$(jq -r '[.mcp | to_entries[] | select(.value.enabled == true) | .key] | join(",")' \
    "$TEST_ROOT/.github/agent-runtime/review.json")" = "github_read" ]
  [ "$(jq -r '.mcp.github_read.headers["X-MCP-Readonly"]' \
    "$TEST_ROOT/.github/agent-runtime/review.json")" = "true" ]
  [ "$(jq -r '.mcp.github_read.headers["X-MCP-Lockdown"]' \
    "$TEST_ROOT/.github/agent-runtime/review.json")" = "true" ]
}
