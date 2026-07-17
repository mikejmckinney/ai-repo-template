#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "provider MCP configurations stay aligned" {
  run jq -e '
    .mcp.supabase == {
      type: "remote",
      url: "https://mcp.supabase.com/mcp?project_ref={env:SUPABASE_PROJECT_REF}",
      enabled: false
    } and
    .mcp.netlify.url == "https://netlify-mcp.netlify.app/mcp" and
    .mcp.vercel.url == "https://mcp.vercel.com" and
    .mcp["cloudflare-api"].url == "https://mcp.cloudflare.com/mcp" and
    .mcp["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    .mcp.railway.command == ["railway", "mcp"]
  ' "$REPO_ROOT/.opencode/opencode.json"
  [ "$status" -eq 0 ]

  run jq -e '
    .mcpServers.supabase.url == "https://mcp.supabase.com/mcp?project_ref=${SUPABASE_PROJECT_REF}" and
    .mcpServers.netlify.url == "https://netlify-mcp.netlify.app/mcp" and
    .mcpServers.vercel.url == "https://mcp.vercel.com" and
    .mcpServers["cloudflare-api"].url == "https://mcp.cloudflare.com/mcp" and
    .mcpServers["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    .mcpServers.railway.command == "railway" and
    .mcpServers.railway.args == ["mcp"]
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
