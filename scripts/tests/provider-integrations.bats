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
    .mcp["cloudflare-api"] == {
      type: "remote",
      url: "https://mcp.cloudflare.com/mcp",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:CLOUDFLARE_API_KEY}"}
    } and
    .mcp["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    .mcp.railway == {
      type: "remote",
      url: "https://mcp.railway.com",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:RAILWAY_API_KEY}"}
    }
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
    .mcpServers["cloudflare-api"].headers.Authorization == "Bearer ${CLOUDFLARE_API_KEY}" and
    .mcpServers["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    .mcpServers.railway.type == "http" and
    .mcpServers.railway.url == "https://mcp.railway.com" and
    .mcpServers.railway.headers.Authorization == "Bearer ${RAILWAY_API_KEY}"
  ' "$REPO_ROOT/.mcp.json"
  [ "$status" -eq 0 ]
}

@test "cloud MCP configurations are pinned and aligned" {
  # shellcheck disable=SC2016
  aws_command='exec uvx mcp-proxy-for-aws@1.6.3 "https://aws-mcp.${AWS_REGION:-us-east-1}.api.aws/mcp" --profile "${AWS_PROFILE:-default}" --region "${AWS_REGION:-us-east-1}"'
  # shellcheck disable=SC2016
  oci_command='[[ "${OCI_MCP_ENABLED:-false}" == "true" ]] || { echo "OCI MCP is disabled; set OCI_MCP_ENABLED=true to opt in" >&2; exit 1; }; exec uvx --python 3.13 oracle.oci-cloud-mcp-server@2.1.0'

  run jq -e --arg aws_command "$aws_command" --arg oci_command "$oci_command" '
    .mcp.aws == {
      type: "local",
      command: ["bash", "-lc", $aws_command],
      enabled: true
    } and
    .mcp.azure == {
      type: "local",
      command: ["npx", "-y", "@azure/mcp@2.0.5", "server", "start"],
      enabled: true
    } and
    .mcp.oci == {
      type: "local",
      command: ["uvx", "--python", "3.13", "oracle.oci-cloud-mcp-server@2.1.0"],
      enabled: false,
      env: {
        OCI_CONFIG_PROFILE: "{env:OCI_CONFIG_PROFILE}",
        FASTMCP_LOG_LEVEL: "ERROR"
      }
    } and
    .mcp.render == {
      type: "remote",
      url: "https://mcp.render.com/mcp",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:RENDER_API_KEY}"}
    }
  ' "$REPO_ROOT/.opencode/opencode.json"
  [ "$status" -eq 0 ]

  run jq -e --arg aws_command "$aws_command" --arg oci_command "$oci_command" '
    .mcpServers.aws == {
      command: "bash",
      args: ["-lc", $aws_command]
    } and
    .mcpServers.azure == {
      command: "npx",
      args: ["-y", "@azure/mcp@2.0.5", "server", "start"]
    } and
    .mcpServers.oci == {
      command: "bash",
      args: ["-lc", $oci_command],
      disabled: true,
      env: {
        OCI_CONFIG_PROFILE: "${OCI_CONFIG_PROFILE}",
        FASTMCP_LOG_LEVEL: "ERROR"
      }
    } and
    .mcpServers.render == {
      type: "http",
      url: "https://mcp.render.com/mcp",
      headers: {Authorization: "Bearer ${RENDER_API_KEY}"}
    }
  ' "$REPO_ROOT/.mcp.json"
  [ "$status" -eq 0 ]
}

@test "locked agent profiles disable account-connected cloud MCPs" {
  for profile in review fix; do
    run jq -e '
      .mcp.aws == {type: "local", command: ["false"], enabled: false} and
      .mcp.azure == {type: "local", command: ["false"], enabled: false} and
      .mcp.oci == {type: "local", command: ["false"], enabled: false} and
      .mcp.render == {enabled: false}
    ' "$REPO_ROOT/.github/agent-runtime/$profile.json"
    [ "$status" -eq 0 ]
  done
}

@test "GCP and Colyseus MCPs remain deferred" {
  run jq -e '(.mcp | has("gcp") or has("colyseus")) | not' \
    "$REPO_ROOT/.opencode/opencode.json"
  [ "$status" -eq 0 ]
  run jq -e '(.mcpServers | has("gcp") or has("colyseus")) | not' \
    "$REPO_ROOT/.mcp.json"
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

@test "complete official Phaser 4 skill set is nested under one parent" {
  phaser_skills=(
    actions-and-utilities animations audio-and-sound cameras curves-and-paths
    data-manager events-system filters-and-postfx game-object-components
    game-setup-and-config geometry-and-math graphics-and-shapes
    groups-and-containers input-keyboard-mouse-touch loading-assets particles
    physics-arcade physics-matter render-textures scale-and-responsive scenes
    sprites-and-images text-and-bitmaptext tilemaps time-and-timers tweens
    v3-to-v4-migration v4-new-features
  )

  run find "$REPO_ROOT/.agents/skills/phaser" -mindepth 2 -maxdepth 2 \
    -type f -name SKILL.md -printf '%h\n'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq "${#phaser_skills[@]}" ]

  for skill in "${phaser_skills[@]}"; do
    [ -f "$REPO_ROOT/.agents/skills/phaser/$skill/SKILL.md" ]
    [ ! -e "$REPO_ROOT/.agents/skills/$skill" ]
    run jq -e --arg skill "$skill" '
      .skills[$skill].source == "phaserjs/phaser" and
      .skills[$skill].ref == "41be1e462bc600064e498cba370bfa8c5c055a22" and
      .skills[$skill].sourceType == "github" and
      .skills[$skill].skillPath == ("skills/" + $skill)
    ' "$REPO_ROOT/skills-lock.json"
    [ "$status" -eq 0 ]
  done

  run jq -e '[.skills[] | select(.source == "phaserjs/phaser")] | length == 28' \
    "$REPO_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "multi-skill providers are nested under provider parents" {
  provider_skills=(
    "vercel/deploy-to-vercel"
    "vercel/vercel-composition-patterns"
    "vercel/vercel-react-best-practices"
    "vercel/vercel-react-view-transitions"
    "netlify/netlify-config"
    "netlify/netlify-deploy"
    "netlify/netlify-frameworks"
    "supabase/supabase"
    "supabase/supabase-postgres-best-practices"
    "cloudflare/workers-best-practices"
    "cloudflare/wrangler"
  )

  for provider_skill in "${provider_skills[@]}"; do
    skill="${provider_skill#*/}"
    [ -f "$REPO_ROOT/.agents/skills/$provider_skill/SKILL.md" ]
    [ ! -f "$REPO_ROOT/.agents/skills/$skill/SKILL.md" ]
  done

  [ -f "$REPO_ROOT/.agents/skills/use-railway/SKILL.md" ]
}
