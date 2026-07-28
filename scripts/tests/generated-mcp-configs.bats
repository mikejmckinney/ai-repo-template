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

@test "local npm MCP launchers use exact reviewed packages" {
  run jq -e '
    .servers.playwright.command == ["bash", "scripts/browser-mcp.sh", "playwright", "@playwright/mcp@0.0.78"] and
    .servers["chrome-devtools"].command == ["bash", "scripts/browser-mcp.sh", "chrome-devtools", "chrome-devtools-mcp@1.6.0"] and
    .servers.shadcn.command == ["npx", "-y", "shadcn@4.13.1", "mcp"] and
    ([.servers[].command? // [] | .[] | select(type == "string" and contains("@latest"))] | length) == 0
  ' "$REPO_ROOT/.config/mcp-inventory.json"

  [ "$status" -eq 0 ]
}

@test "audio MCP launchers use exact reviewed packages and credential names" {
  run jq -e '
    .servers.elevenlabs.command == ["bash", "scripts/elevenlabs-mcp.sh"] and
    .servers.elevenlabs.environment == {"ELEVENLABS_API_KEY": "ELEVENLABS_API_KEY"} and
    .servers.mureka.command == ["bash", "scripts/mureka-mcp.sh"] and
    .servers.mureka.environment == {"MUREKA_API_KEY": "MUREKA_API_KEY"} and
    .servers.suno.command == ["bash", "scripts/suno-mcp.sh"] and
    .servers.suno.environment == {"ACEDATACLOUD_API_TOKEN": "ACEDATACLOUD_API_TOKEN"}
  ' "$REPO_ROOT/.config/mcp-inventory.json"

  [ "$status" -eq 0 ]

  run jq -e '
    .mcpServers.elevenlabs.command == "bash" and
    .mcpServers.elevenlabs.args == ["scripts/elevenlabs-mcp.sh"] and
    .mcpServers.elevenlabs.env.ELEVENLABS_API_KEY == "${ELEVENLABS_API_KEY}" and
    .mcpServers.mureka.command == "bash" and
    .mcpServers.mureka.args == ["scripts/mureka-mcp.sh"] and
    .mcpServers.mureka.env.MUREKA_API_KEY == "${MUREKA_API_KEY}" and
    .mcpServers.suno.command == "bash" and
    .mcpServers.suno.args == ["scripts/suno-mcp.sh"] and
    .mcpServers.suno.env.ACEDATACLOUD_API_TOKEN == "${ACEDATACLOUD_API_TOKEN}"
  ' "$REPO_ROOT/.mcp.json"

  [ "$status" -eq 0 ]
}

@test "unmigrated audio MCP launchers pin the compatible Python SDK" {
  run grep -Fq 'exec uvx --python 3.13 --with "mcp==1.29.0" mureka-mcp==0.0.13' \
    "$REPO_ROOT/scripts/mureka-mcp.sh"
  [ "$status" -eq 0 ]

  run grep -Fq 'exec uvx --python 3.13 --with "mcp==1.29.0" mcp-suno==2026.7.4.0' \
    "$REPO_ROOT/scripts/suno-mcp.sh"
  [ "$status" -eq 0 ]
}

@test "audio MCP launchers apply portable non-secret defaults" {
  bin_dir="$(mktemp -d)"
  cat >"$bin_dir/uvx" <<'EOF'
#!/usr/bin/env bash
printf 'args=%s\n' "$*"
printf 'base=%s\n' "${ELEVENLABS_MCP_BASE_PATH:-}"
printf 'output=%s\n' "${ELEVENLABS_MCP_OUTPUT_MODE:-}"
printf 'url=%s\n' "${MUREKA_API_URL:-}"
printf 'timeout=%s\n' "${TIME_OUT_SECONDS:-}"
EOF
  chmod +x "$bin_dir/uvx"

  run env PATH="$bin_dir:$PATH" ELEVENLABS_API_KEY=test-key \
    bash -c 'cd /tmp && bash "$1/scripts/elevenlabs-mcp.sh"' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"args=--python 3.13 elevenlabs-mcp==0.11.0"* ]]
  [[ "$output" == *"base=$REPO_ROOT/.artifacts/audio"* ]]
  [[ "$output" == *"output=files"* ]]

  run env PATH="$bin_dir:$PATH" MUREKA_API_KEY=test-key \
    bash -c 'cd /tmp && bash "$1/scripts/mureka-mcp.sh"' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"args=--python 3.13 --with mcp==1.29.0 mureka-mcp==0.0.13"* ]]
  [[ "$output" == *"url=https://api.mureka.ai"* ]]
  [[ "$output" == *"timeout=300"* ]]

  run env PATH="$bin_dir:$PATH" ACEDATACLOUD_API_TOKEN=test-key \
    bash -c 'cd /tmp && bash "$1/scripts/suno-mcp.sh"' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"args=--python 3.13 --with mcp==1.29.0 mcp-suno==2026.7.4.0"* ]]

  rm -rf "$bin_dir"
}

@test "audio MCP launchers reject missing credentials before package resolution" {
  for launcher in elevenlabs mureka suno; do
    run env -u ELEVENLABS_API_KEY -u MUREKA_API_KEY -u ACEDATACLOUD_API_TOKEN \
      bash "$REPO_ROOT/scripts/$launcher-mcp.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"is required"* ]]
  done
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
  [ "$(jq '[.mcp[].timeout == 60000] | all' "$TEST_ROOT/.opencode/opencode.json")" = "true" ]
  [ "$(jq -r '.mcp.oci.enabled' "$TEST_ROOT/.opencode/opencode.json")" = "false" ]
  [ "$(jq -r '.mcp.github.headers.Authorization' "$TEST_ROOT/.opencode/opencode.json")" = 'Bearer {env:GH_PAT}' ]
  [ "$(jq -r '.mcpServers.github.headers.Authorization' "$TEST_ROOT/.mcp.json")" = 'Bearer ${GH_PAT}' ]
}
