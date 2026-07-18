#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "provider MCP configurations stay aligned" {
  run jq -e '
    .mcp.supabase == {
      type: "remote",
      url: "https://mcp.supabase.com/mcp",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:SUPABASE_API_KEY}"}
    } and
    .mcp.netlify == {
      type: "local",
      command: [
        "bash", "-lc",
        "exec npx -y mcp-remote@0.1.38 https://netlify-mcp.netlify.app/mcp --header \"Authorization:Bearer $NETLIFY_API_KEY\" --transport http-only --silent"
      ],
      enabled: true,
      env: {NETLIFY_API_KEY: "{env:NETLIFY_API_KEY}"}
    } and
    .mcp.vercel == {
      type: "remote",
      url: "https://mcp.vercel.com",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:VERCEL_API_KEY}"}
    } and
    .mcp["cloudflare-api"].url == "https://mcp.cloudflare.com/mcp" and
    .mcp["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    .mcp.railway.command == ["railway", "mcp"] and
    .mcp.railway.env == {RAILWAY_API_TOKEN: "{env:RAILWAY_API_KEY}"}
  ' "$REPO_ROOT/.opencode/opencode.json"
  [ "$status" -eq 0 ]

  run jq -e '
    .mcpServers.supabase.url == "https://mcp.supabase.com/mcp" and
    .mcpServers.supabase.headers.Authorization == "Bearer ${SUPABASE_API_KEY}" and
    .mcpServers.netlify.command == "bash" and
    .mcpServers.netlify.args == [
      "-lc",
      "exec npx -y mcp-remote@0.1.38 https://netlify-mcp.netlify.app/mcp --header \"Authorization:Bearer $NETLIFY_API_KEY\" --transport http-only --silent"
    ] and
    .mcpServers.netlify.env.NETLIFY_API_KEY == "${NETLIFY_API_KEY}" and
    .mcpServers.vercel.url == "https://mcp.vercel.com" and
    .mcpServers.vercel.headers.Authorization == "Bearer ${VERCEL_API_KEY}" and
    .mcpServers["cloudflare-api"].url == "https://mcp.cloudflare.com/mcp" and
    .mcpServers["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    .mcpServers.railway.command == "railway" and
    .mcpServers.railway.args == ["mcp"] and
    .mcpServers.railway.env == {RAILWAY_API_TOKEN: "${RAILWAY_API_KEY}"}
  ' "$REPO_ROOT/.mcp.json"
  [ "$status" -eq 0 ]
}

@test "Codespaces bootstrap copies provider integrations" {
  run python3 - "$REPO_ROOT/install.sh" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"MULTIAGENT_FILES=\(\n(?P<body>.*?)\n\)", text, re.DOTALL)
assert match is not None
for path in ('.agents/skills', '.mcp.json', '.opencode/opencode.json', 'skills-lock.json'):
    assert f'  "{path}"' in match.group("body"), path
PY

  [ "$status" -eq 0 ]
}

@test "OpenDesign MCP uses the portable project launcher" {
  run jq -e '
    .mcp["open-design"].command == ["bash", "scripts/open-design-mcp.sh"]
  ' "$REPO_ROOT/.opencode/opencode.json"
  [ "$status" -eq 0 ]

  run jq -e '
    .mcpServers["open-design"].command == "bash" and
    .mcpServers["open-design"].args == ["scripts/open-design-mcp.sh"]
  ' "$REPO_ROOT/.mcp.json"
  [ "$status" -eq 0 ]

  run grep -R "/Applications/Open Design.app" \
    "$REPO_ROOT/.opencode/opencode.json" "$REPO_ROOT/.mcp.json"
  [ "$status" -eq 1 ]
  [ -x "$REPO_ROOT/scripts/open-design-mcp.sh" ]
}

@test "shared skills have one canonical cross-agent directory" {
  [ -f "$REPO_ROOT/.agents/skills/session-recovery/SKILL.md" ]
  [ -f "$REPO_ROOT/.agents/skills/multi-model-consensus/SKILL.md" ]
  [ ! -e "$REPO_ROOT/.agents/skills/local-consensus" ]
  [ ! -e "$REPO_ROOT/.opencode/skills" ]
  [ "$(readlink "$REPO_ROOT/.claude/skills")" = "../.agents/skills" ]
  [ ! -e "$REPO_ROOT/.agent" ]
}

@test "focused official Phaser 4 skills are installed" {
  for skill in \
    game-setup-and-config scenes loading-assets sprites-and-images \
    input-keyboard-mouse-touch physics-arcade; do
    [ -f "$REPO_ROOT/.agents/skills/$skill/SKILL.md" ]
    run jq -e --arg skill "$skill" '
      .skills[$skill].source == "phaserjs/phaser" and
      .skills[$skill].sourceType == "github"
    ' "$REPO_ROOT/skills-lock.json"
    [ "$status" -eq 0 ]
  done
}
