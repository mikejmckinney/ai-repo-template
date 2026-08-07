#!/usr/bin/env bats

bats_require_minimum_version 1.7.0
export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/mcp-prewarm.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mcp-prewarm.XXXXXX")"
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home" "$TEST_ROOT/runtime"

  cat >"$TEST_ROOT/inventory.json" <<'EOF'
{
  "servers": {
    "aws": {
      "transport": "local",
      "command": ["uvx", "mcp-proxy-for-aws@1.6.3"],
      "prewarm": {
        "kind": "uvx",
        "package": "mcp-proxy-for-aws@1.6.3"
      }
    },
    "playwright": {
      "transport": "local",
      "command": ["npx", "-y", "@playwright/mcp@0.0.78"],
      "prewarm": {
        "kind": "npx",
        "package": "@playwright/mcp@0.0.78",
        "required_commands": ["fake-chrome"]
      }
    },
    "open-design": {
      "transport": "local",
      "command": ["bash", "scripts/open-design-mcp.sh"],
      "prewarm": {
        "kind": "open-design"
      }
    },
    "remote": {
      "transport": "remote",
      "url": "https://example.invalid/mcp"
    }
  }
}
EOF

  cat >"$TEST_ROOT/bin/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npx %s\n' "$*" >>"$HOME/package.log"
if [[ -e "$HOME/fail-$MCP_PREWARM_SERVER" ]]; then
  printf 'secret-value\n' >&2
  exit 42
fi
EOF
  cat >"$TEST_ROOT/bin/uvx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'uvx %s\n' "$*" >>"$HOME/package.log"
if [[ -e "$HOME/fail-$MCP_PREWARM_SERVER" ]]; then
  printf 'secret-value\n' >&2
  exit 42
fi
EOF
  cat >"$TEST_ROOT/bin/fake-chrome" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_ROOT/bin/npx" "$TEST_ROOT/bin/uvx" "$TEST_ROOT/bin/fake-chrome"

  cat >"$TEST_ROOT/open-design" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$HOME/open-design.log"
if [[ -e "$HOME/fail-open-design" ]]; then
  printf 'secret-value\n' >&2
  exit 9
fi
EOF
  chmod +x "$TEST_ROOT/open-design"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

run_prewarm() {
  run env HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" \
    MCP_PREWARM_INVENTORY="$TEST_ROOT/inventory.json" \
    MCP_PREWARM_RUNTIME_DIR="$TEST_ROOT/runtime" \
    MCP_PREWARM_OPEN_DESIGN_SCRIPT="$TEST_ROOT/open-design" \
    MCP_PREWARM_JOBS=2 MCP_PREWARM_TIMEOUT_SECONDS=5 \
    bash "$SCRIPT" "$@"
}

@test "prewarm resolves exact inventory packages and verifies Open Design readiness" {
  run_prewarm

  [ "$status" -eq 0 ]
  [[ "$output" == *"server=aws status=prepared"* ]]
  [[ "$output" == *"server=playwright status=prepared"* ]]
  [[ "$output" == *"server=open-design status=healthy"* ]]
  run grep -F -- 'uvx --from mcp-proxy-for-aws@1.6.3 python -c' "$TEST_ROOT/home/package.log"
  [ "$status" -eq 0 ]
  run grep -F -- 'npx --yes --package @playwright/mcp@0.0.78 -- node --version' \
    "$TEST_ROOT/home/package.log"
  [ "$status" -eq 0 ]
  [ "$(<"$TEST_ROOT/home/open-design.log")" = "--daemon-only" ]
}

@test "canonical prewarm metadata covers every enabled local launcher" {
  run jq -e '
    . as $root |
    all(.servers | to_entries[] |
      select((.value.transport == "local" or .value.opencode.command?) and .value.enabled != false);
      .value.prewarm.kind) and
    $root.servers.netlify.prewarm == {kind: "npx", package: "mcp-remote@0.1.38"} and
    $root.servers.aws.prewarm == {kind: "uvx", package: "mcp-proxy-for-aws@1.6.3"} and
    $root.servers.azure.prewarm == {kind: "npx", package: "@azure/mcp@2.0.5"} and
    $root.servers.elevenlabs.prewarm == {kind: "uvx", python: "3.13", package: "elevenlabs-mcp==0.11.0"} and
    $root.servers.mureka.prewarm == {kind: "uvx", python: "3.13", package: "mureka-mcp==0.0.13", with: ["mcp==1.29.0"]} and
    $root.servers.suno.prewarm == {kind: "uvx", python: "3.13", package: "mcp-suno==2026.7.4.0", with: ["mcp==1.29.0"]} and
    $root.servers["open-design"].prewarm == {kind: "open-design"} and
    $root.servers.playwright.prewarm == {kind: "npx", package: "@playwright/mcp@0.0.78", required_commands: ["google-chrome-for-testing"]} and
    $root.servers["chrome-devtools"].prewarm == {kind: "npx", package: "chrome-devtools-mcp@1.6.0", required_commands: ["google-chrome-for-testing"]} and
    $root.servers.shadcn.prewarm == {kind: "npx", package: "shadcn@4.13.1"}
  ' "$REPO_ROOT/.config/mcp-inventory.json"

  [ "$status" -eq 0 ]
}

@test "full prewarm is repeatable with stable package arguments" {
  run_prewarm
  [ "$status" -eq 0 ]
  package_runs="$(wc -l <"$TEST_ROOT/home/package.log" | tr -d ' ')"

  run_prewarm

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$TEST_ROOT/home/package.log" | tr -d ' ')" -eq "$((package_runs * 2))" ]
  [ "$(grep -Fc 'uvx --from mcp-proxy-for-aws@1.6.3 python -c' "$TEST_ROOT/home/package.log")" -eq 2 ]
  [ "$(grep -Fc 'npx --yes --package @playwright/mcp@0.0.78 -- node --version' "$TEST_ROOT/home/package.log")" -eq 2 ]
  [ "$(wc -l <"$TEST_ROOT/home/open-design.log" | tr -d ' ')" -eq 2 ]
}

@test "readiness-only mode does not resolve packages" {
  run_prewarm
  [ "$status" -eq 0 ]
  package_runs="$(wc -l <"$TEST_ROOT/home/package.log" | tr -d ' ')"

  run_prewarm --readiness-only

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$TEST_ROOT/home/package.log" | tr -d ' ')" -eq "$package_runs" ]
  [ "$(wc -l <"$TEST_ROOT/home/open-design.log" | tr -d ' ')" -eq 2 ]
}

@test "prewarm reports missing required commands before package resolution" {
  jq '.servers = {playwright: (.servers.playwright | .prewarm.required_commands = ["missing-chrome"])}' \
    "$TEST_ROOT/inventory.json" >"$TEST_ROOT/missing.json"

  run env HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" \
    MCP_PREWARM_INVENTORY="$TEST_ROOT/missing.json" \
    MCP_PREWARM_RUNTIME_DIR="$TEST_ROOT/runtime" \
    MCP_PREWARM_OPEN_DESIGN_SCRIPT="$TEST_ROOT/open-design" \
    bash "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required command missing-chrome for playwright"* ]]
  [ ! -e "$TEST_ROOT/home/package.log" ]
}

@test "prewarm bounds package failures without exposing command output" {
  touch "$TEST_ROOT/home/fail-aws"

  run_prewarm

  [ "$status" -ne 0 ]
  [[ "$output" == *"package resolution failed"* ]]
  [[ "$output" == *"aws"* ]]
  [[ "$output" != *"secret-value"* ]]
  [[ "$output" != *"Open Design readiness failed"* ]]
}

@test "prewarm distinguishes Open Design readiness failure from package resolution" {
  touch "$TEST_ROOT/home/fail-open-design"

  run_prewarm --readiness-only

  [ "$status" -ne 0 ]
  [[ "$output" == *"Open Design readiness failed"* ]]
  [[ "$output" != *"package resolution failed"* ]]
  [[ "$output" != *"secret-value"* ]]
}
