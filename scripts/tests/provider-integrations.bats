#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "provider MCP configurations stay aligned" {
  run jq -e '
    (.mcp | with_entries(.value |= del(.timeout))) as $mcp |
    $mcp.supabase == {
      type: "remote",
      url: "https://mcp.supabase.com/mcp",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:SUPABASE_API_KEY}"}
    } and
    $mcp.netlify == {
      type: "local",
      command: [
        "npx", "-y", "mcp-remote@0.1.38",
        "https://netlify-mcp.netlify.app/mcp",
        "--header", "Authorization:Bearer ${NETLIFY_API_KEY}",
        "--transport", "http-only", "--silent"
      ],
      enabled: true,
      environment: {NETLIFY_API_KEY: "{env:NETLIFY_API_KEY}"}
    } and
    $mcp.vercel == {
      type: "remote",
      url: "https://mcp.vercel.com",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:VERCEL_API_KEY}"}
    } and
    $mcp["cloudflare-api"] == {
      type: "remote",
      url: "https://mcp.cloudflare.com/mcp",
      enabled: true,
      oauth: false,
      headers: {Authorization: "Bearer {env:CLOUDFLARE_API_KEY}"}
    } and
    $mcp["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    $mcp.railway == {
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
    .mcpServers.netlify.type == "http" and
    .mcpServers.netlify.url == "https://netlify-mcp.netlify.app/mcp" and
    .mcpServers.netlify.headers.Authorization == "Bearer ${NETLIFY_API_KEY}" and
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
    (.mcp | with_entries(.value |= del(.timeout))) as $mcp |
    $mcp.aws == {
      type: "local",
      command: ["bash", "-lc", $aws_command],
      enabled: true
    } and
    $mcp.azure == {
      type: "local",
      command: ["npx", "-y", "@azure/mcp@2.0.5", "server", "start"],
      enabled: true
    } and
    $mcp.oci == {
      type: "local",
      command: ["uvx", "--python", "3.13", "oracle.oci-cloud-mcp-server@2.1.0"],
      enabled: false,
      env: {
        OCI_CONFIG_PROFILE: "{env:OCI_CONFIG_PROFILE}",
        FASTMCP_LOG_LEVEL: "ERROR"
      }
    } and
    $mcp.render == {
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
      .mcp.render == {enabled: false} and
      .mcp.suno == {type: "local", command: ["false"], enabled: false}
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

@test "repository includes provider integrations" {
  for path in \
    .agents/skills .cursor .config/codespace-tools.json .mcp.json \
    docs/guides/cloud-provider-tooling.md docs/guides/skill-supply-chain.md \
    .opencode/opencode.json scripts/browser-mcp.sh scripts/elevenlabs-mcp.sh \
    scripts/mureka-mcp.sh scripts/suno-mcp.sh scripts/install-codespace-tools.sh \
    scripts/open-design-mcp.sh scripts/scan-skill-secrets.py \
    scripts/skill-supply-chain.py skills-lock.json CLAUDE.md; do
    [ -e "$REPO_ROOT/$path" ]
  done
}

@test "Claude Code entrypoint is an exact installed pointer" {
  run python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
assert (root / "CLAUDE.md").read_bytes() == b"@AGENTS.md\n"
required = (root / "scripts/checks/010-required-files.sh").read_text(encoding="utf-8")
assert '  "CLAUDE.md"' in required
PY
  [ "$status" -eq 0 ]
}

@test "script syntax check discovers only lock-declared owned skill scripts" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/scripts/checks" "$tmp/.agents/skills/owned/scripts" "$tmp/.agents/skills/vendor/scripts"
  cp "$REPO_ROOT/scripts/checks/055-script-syntax.sh" "$tmp/scripts/checks/"
  printf '%s\n' 'if then' >"$tmp/.agents/skills/owned/scripts/bad.sh"
  printf '%s\n' 'if then' >"$tmp/.agents/skills/vendor/scripts/vendor-bad.sh"
  cat >"$tmp/skills-lock.json" <<'EOF'
{"ownedSkills":{"owned":{"destinationPath":".agents/skills/owned"}},"skills":{"vendor":{"destinationPath":".agents/skills/vendor"}}}
EOF
  run bash -c '
    cd "$1"
    PASS=0
    FAIL=0
    WARN=0
    pass() { PASS=$((PASS + 1)); }
    fail() { FAIL=$((FAIL + 1)); }
    warn() { WARN=$((WARN + 1)); }
    source scripts/checks/055-script-syntax.sh
    [[ "$FAIL" -eq 1 ]]
  ' _ "$tmp"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "Cursor uses the canonical root MCP configuration" {
  [ -L "$REPO_ROOT/.cursor/mcp.json" ]
  [ "$(readlink "$REPO_ROOT/.cursor/mcp.json")" = "../.mcp.json" ]
  [ "$(realpath "$REPO_ROOT/.cursor/mcp.json")" = "$REPO_ROOT/.mcp.json" ]
}

@test "official AWS successor and complete Azure catalogs are installed" {
  run jq -e '
    ([.skills[] | select(.source == "aws/agent-toolkit-for-aws")] | length) == 19 and
    ([.skills[] | select(.source == "awslabs/agent-plugins")] | length) == 0 and
    ([.skills[] | select(.source == "microsoft/azure-skills")] | length) == 26 and
    ([.skills[] | select(.source == "aws/agent-toolkit-for-aws") | .ref] | unique | length) == 1 and
    ([.skills[] | select(.source == "microsoft/azure-skills") | .ref] | unique | length) == 1 and
    all(.skills[] | select(.source == "aws/agent-toolkit-for-aws");
      (.ref | test("^[0-9a-f]{40}$")) and
      (.skillPath | startswith("skills/")) and
      (.destinationPath | startswith(".agents/skills/aws/"))) and
    all(.skills[] | select(.source == "microsoft/azure-skills");
      (.ref | test("^[0-9a-f]{40}$")) and
      (.skillPath | startswith("skills/")) and
      (.destinationPath | startswith(".agents/skills/azure/")))
  ' "$REPO_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]

  run find "$REPO_ROOT/.agents/skills/aws" -type f -name SKILL.md
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 19 ]

  azure_skills=(
    airunway-aks-setup appinsights-instrumentation azure-ai azure-aigateway
    azure-cloud-migrate azure-compliance azure-compute azure-cost azure-deploy
    azure-diagnostics azure-enterprise-infra-planner azure-kubernetes azure-kusto
    azure-messaging azure-prepare azure-quotas azure-reliability
    azure-resource-lookup azure-resource-visualizer azure-storage azure-upgrade
    azure-validate entra-agent-id entra-app-registration microsoft-foundry
    python-appservice-deploy
  )
  for skill in "${azure_skills[@]}"; do
    [ -f "$REPO_ROOT/.agents/skills/azure/$skill/SKILL.md" ]
  done
}

@test "requested audio skills use reviewed immutable packages" {
  run jq -e '
    .skills["skywork-music-maker"] == {
      "computedHash": .skills["skywork-music-maker"].computedHash,
      "destinationPath": ".agents/skills/skywork/skywork-music-maker",
      "hashAlgorithm": "sha256-tree-v1",
      "ref": "c8c6aeb742c3d6a2b728992142796702464b6fce",
      "skillPath": "skywork-music-maker",
      "source": "SkyworkAI/Skywork-Skills",
      "sourceType": "github"
    } and
    .skills["sound-effects"].destinationPath == ".agents/skills/elevenlabs/sound-effects" and
    .skills["sound-effects"].skillPath == "sound-effects" and
    .skills["sound-effects"].source == "elevenlabs/skills" and
    .skills["sound-effects"].ref == "37c0f2a682a8953cb9f09b152a0e1624d234193e" and
    .skills.music.destinationPath == ".agents/skills/elevenlabs/music" and
    .skills.music.skillPath == "music" and
    .skills.music.source == "elevenlabs/skills" and
    .skills.music.ref == "37c0f2a682a8953cb9f09b152a0e1624d234193e" and
    .sourceMetadata["SkyworkAI/Skywork-Skills"].license == "MIT" and
    .sourceMetadata["elevenlabs/skills"].license == "MIT"
  ' "$REPO_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]

  [ -f "$REPO_ROOT/.agents/skills/skywork/skywork-music-maker/SKILL.md" ]
  [ -f "$REPO_ROOT/.agents/skills/elevenlabs/sound-effects/SKILL.md" ]
  [ -f "$REPO_ROOT/.agents/skills/elevenlabs/music/SKILL.md" ]
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
  [ -x "$REPO_ROOT/scripts/hyperframes.sh" ]
  [ -x "$REPO_ROOT/scripts/install-media-tools.sh" ]
  [ -x "$REPO_ROOT/scripts/test-media-tools-live.sh" ]
  [ -x "$REPO_ROOT/scripts/open-design-mcp-smoke.py" ]

  run grep -F 'export COREPACK_ENABLE_DOWNLOAD_PROMPT=0' \
    "$REPO_ROOT/.agents/skills/open-design/scripts/bootstrap.sh"
  [ "$status" -eq 0 ]
}

@test "OpenDesign bootstrap pins Studio and complete catalogs" {
  lock="$REPO_ROOT/.agents/skills/open-design/open-design.lock"
  bootstrap="$REPO_ROOT/.agents/skills/open-design/scripts/bootstrap.sh"
  skill="$REPO_ROOT/.agents/skills/open-design/SKILL.md"

  run grep -Fx 'ref: open-design-v0.17.0' "$lock"
  [ "$status" -eq 0 ]
  run grep -Fx 'commit: 90a660add511da6408464a1bf3d4d5945ad06400' "$lock"
  [ "$status" -eq 0 ]
  run grep -Fx 'node: ~24' "$lock"
  [ "$status" -eq 0 ]
  run grep -Fx 'pnpm: 10.33.2' "$lock"
  [ "$status" -eq 0 ]

  for required in \
    'apps/daemon' 'apps/web' 'design-systems' 'design-templates' \
    'prompt-templates' 'skills' '@open-design/web^...' \
    'pnpm --filter @open-design/web run build:sidecar' \
    'export NEXT_TELEMETRY_DISABLED=1' '${lock_node#\~}' \
    'git fetch --no-tags origin "$lock_commit"'; do
    run grep -F "$required" "$bootstrap"
    [ "$status" -eq 0 ]
  done

  run grep -F "If the current task prohibits subagents, do not call it" "$skill"
  [ "$status" -eq 0 ]
}

@test "HyperFrames renderer and skills use immutable reviewed pins" {
  wrapper="$REPO_ROOT/scripts/hyperframes.sh"
  expected_skills='["hyperframes","hyperframes-animation","hyperframes-cli","hyperframes-core","hyperframes-creative","media-use","motion-graphics","product-launch-video"]'

  run bash "$wrapper" --print-version-pin
  [ "$status" -eq 0 ]
  [ "$output" = '0.7.90' ]
  run grep -F 'export HYPERFRAMES_SKIP_SKILLS=1' "$wrapper"
  [ "$status" -eq 0 ]

  run jq -e --argjson expected "$expected_skills" '
    [.skills | to_entries[] | select(.value.source == "heygen-com/hyperframes") | .key] as $names |
    ($names | sort) == $expected and
    all(.skills | to_entries[] | select(.value.source == "heygen-com/hyperframes");
      .value.ref == "1e51eaec2cb6c058fbb5349c8c3dae9770d7f30c" and
      .value.destinationPath == (".agents/skills/hyperframes/" + .key)
    ) and
    .sourceMetadata["heygen-com/hyperframes"] == {
      license: "Apache-2.0",
      evidence: [{label: "LICENSE", path: "LICENSE"}]
    }
  ' "$REPO_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]

  for skill in $(jq -r '.[]' <<<"$expected_skills"); do
    [ -f "$REPO_ROOT/.agents/skills/hyperframes/$skill/SKILL.md" ]
  done
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

@test "Anthropic skills share one locked provider parent" {
  anthropic_skills=(frontend-design mcp-builder skill-creator)

  for skill in "${anthropic_skills[@]}"; do
    [ -f "$REPO_ROOT/.agents/skills/anthropic/$skill/SKILL.md" ]
    [ -f "$REPO_ROOT/.agents/skills/anthropic/$skill/LICENSE.txt" ]
    [ ! -e "$REPO_ROOT/.agents/skills/$skill" ]
    run jq -e --arg skill "$skill" '
      .skills[$skill].source == "anthropics/skills" and
      .skills[$skill].ref == "fa0fa64bdc967915dc8399e803be67759e1e62b8" and
      .skills[$skill].skillPath == ("skills/" + $skill) and
      .skills[$skill].destinationPath == (".agents/skills/anthropic/" + $skill) and
      .skills[$skill].hashAlgorithm == "sha256-tree-v1"
    ' "$REPO_ROOT/skills-lock.json"
    [ "$status" -eq 0 ]
  done
}

@test "repository-owned provider skills are explicit and complete" {
  for skill in gcp colyseus suno; do
    [ -f "$REPO_ROOT/.agents/skills/$skill/SKILL.md" ]
    run jq -e --arg skill "$skill" '
      .ownedSkills[$skill].destinationPath == (".agents/skills/" + $skill) and
      (.skills | has($skill) | not)
    ' "$REPO_ROOT/skills-lock.json"
    [ "$status" -eq 0 ]
    run grep -q '## Ownership and freshness' "$REPO_ROOT/.agents/skills/$skill/SKILL.md"
    [ "$status" -eq 0 ]
  done

  for topic in "Cloud Run" GKE "Compute Engine" Terraform; do
    run grep -Fq "$topic" "$REPO_ROOT/.agents/skills/gcp/SKILL.md"
    [ "$status" -eq 0 ]
  done
  for topic in rooms "state synchronization" matchmaking "unit testing" \
    "load testing" deployment scalability "Colyseus Cloud"; do
    run grep -Fq "$topic" "$REPO_ROOT/.agents/skills/colyseus/SKILL.md"
    [ "$status" -eq 0 ]
  done
  run grep -q 'https://docs.colyseus.io/' "$REPO_ROOT/.agents/skills/colyseus/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -q 'https://cloud.google.com/' "$REPO_ROOT/.agents/skills/gcp/SKILL.md"
  [ "$status" -eq 0 ]

  for phrase in "Ace Data Cloud" "third-party" "explicit approval" \
    ACEDATACLOUD_API_TOKEN suno_generate_music suno_get_task \
    "response.success" succeeded "streaming previews"; do
    run grep -Fq "$phrase" "$REPO_ROOT/.agents/skills/suno/SKILL.md"
    [ "$status" -eq 0 ]
  done

  run grep -Fq 'https://github.com/AceDataCloud/SunoMCP/commit/0473b0ba5d454e2dd1eafdd06828627d06c23774' \
    "$REPO_ROOT/.agents/skills/suno/SKILL.md"
  [ "$status" -eq 0 ]

  for url in \
    'https://platform.acedata.cloud/services/suno?tab=pricing' \
    'https://platform.acedata.cloud/documents/suno-audios'; do
    run grep -Fq "$url" "$REPO_ROOT/.agents/skills/suno/SKILL.md"
    [ "$status" -eq 0 ]
  done

  run grep -Fq "or an AI song" "$REPO_ROOT/.agents/skills/suno/SKILL.md"
  [ "$status" -eq 1 ]
}
