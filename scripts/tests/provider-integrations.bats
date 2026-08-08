#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "cloud MCP inventory retains reviewed endpoints pins and deferrals" {
  run jq -e '
    .servers.supabase.url == "https://mcp.supabase.com/mcp" and
    .servers.netlify.url == "https://netlify-mcp.netlify.app/mcp" and
    .servers.netlify.opencode.command[2] == "mcp-remote@0.1.38" and
    .servers.vercel.url == "https://mcp.vercel.com" and
    .servers["cloudflare-api"].url == "https://mcp.cloudflare.com/mcp" and
    .servers["cloudflare-docs"].url == "https://docs.mcp.cloudflare.com/mcp" and
    .servers.railway.url == "https://mcp.railway.com" and
    (.servers.aws.command[2] | contains("mcp-proxy-for-aws@1.6.3")) and
    .servers.azure.command[2] == "@azure/mcp@2.0.5" and
    .servers.oci.command == ["uvx", "--python", "3.13", "oracle.oci-cloud-mcp-server@2.1.0"] and
    .servers.oci.enabled == false and
    .servers.render.url == "https://mcp.render.com/mcp" and
    ((.servers | has("gcp") or has("colyseus")) | not)
  ' "$REPO_ROOT/.config/mcp-inventory.json"
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

@test "external provider catalogs retain reviewed sources refs and nesting" {
  azure_skills='["airunway-aks-setup","appinsights-instrumentation","azure-ai","azure-aigateway","azure-cloud-migrate","azure-compliance","azure-compute","azure-cost","azure-deploy","azure-diagnostics","azure-enterprise-infra-planner","azure-kubernetes","azure-kusto","azure-messaging","azure-prepare","azure-quotas","azure-reliability","azure-resource-lookup","azure-resource-visualizer","azure-storage","azure-upgrade","azure-validate","entra-agent-id","entra-app-registration","microsoft-foundry","python-appservice-deploy"]'
  phaser_skills='["actions-and-utilities","animations","audio-and-sound","cameras","curves-and-paths","data-manager","events-system","filters-and-postfx","game-object-components","game-setup-and-config","geometry-and-math","graphics-and-shapes","groups-and-containers","input-keyboard-mouse-touch","loading-assets","particles","physics-arcade","physics-matter","render-textures","scale-and-responsive","scenes","sprites-and-images","text-and-bitmaptext","tilemaps","time-and-timers","tweens","v3-to-v4-migration","v4-new-features"]'

  run jq -e --argjson azure "$azure_skills" --argjson phaser "$phaser_skills" '
    . as $root |
    ([.skills | to_entries[] | select(.value.source == "aws/agent-toolkit-for-aws")] | length) == 19 and
    ([.skills | to_entries[] | select(.value.source == "awslabs/agent-plugins")] | length) == 0 and
    all(.skills | to_entries[] | select(.value.source == "aws/agent-toolkit-for-aws");
      .value.ref == "b4416dddac9b6a0cc5412136e6dbf8f07ffdb31c" and
      (.value.destinationPath | startswith(".agents/skills/aws/"))) and
    ([.skills | to_entries[] | select(.value.source == "microsoft/azure-skills") | .key] | sort) == ($azure | sort) and
    all($azure[]; . as $key | $root.skills[$key].ref == "1b592c63641049ff33e4952c4021c63b4507f147" and
      ($root.skills[$key].destinationPath | startswith(".agents/skills/azure/"))) and
    ([.skills | to_entries[] | select(.value.source == "phaserjs/phaser") | .key] | sort) == ($phaser | sort) and
    all($phaser[]; . as $key | $root.skills[$key].ref == "41be1e462bc600064e498cba370bfa8c5c055a22" and
      $root.skills[$key].destinationPath == (".agents/skills/phaser/" + $key)) and
    all(["frontend-design", "mcp-builder", "skill-creator"][]; . as $key |
      $root.skills[$key].source == "anthropics/skills" and
      $root.skills[$key].ref == "fa0fa64bdc967915dc8399e803be67759e1e62b8" and
      $root.skills[$key].destinationPath == (".agents/skills/anthropic/" + $key))
  ' "$REPO_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "requested audio and multi-skill provider packages remain declared" {
  run jq -e '
    . as $root |
    .skills["skywork-music-maker"].source == "SkyworkAI/Skywork-Skills" and
    .skills["skywork-music-maker"].ref == "c8c6aeb742c3d6a2b728992142796702464b6fce" and
    .skills["skywork-music-maker"].destinationPath == ".agents/skills/skywork/skywork-music-maker" and
    all(["music", "sound-effects"][]; . as $key |
      $root.skills[$key].source == "elevenlabs/skills" and
      $root.skills[$key].ref == "37c0f2a682a8953cb9f09b152a0e1624d234193e" and
      $root.skills[$key].destinationPath == (".agents/skills/elevenlabs/" + $key)) and
    all(["deploy-to-vercel", "vercel-composition-patterns", "vercel-react-best-practices", "vercel-react-view-transitions"][]; . as $key |
      $root.skills[$key].destinationPath == (".agents/skills/vercel/" + $key)) and
    all(["netlify-config", "netlify-deploy", "netlify-frameworks"][]; . as $key |
      $root.skills[$key].destinationPath == (".agents/skills/netlify/" + $key)) and
    all(["supabase", "supabase-postgres-best-practices"][]; . as $key |
      $root.skills[$key].destinationPath == (".agents/skills/supabase/" + $key)) and
    all(["workers-best-practices", "wrangler"][]; . as $key |
      $root.skills[$key].destinationPath == (".agents/skills/cloudflare/" + $key)) and
    .skills["use-railway"].destinationPath == ".agents/skills/use-railway"
  ' "$REPO_ROOT/skills-lock.json"
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

@test "OpenDesign MCP uses the portable project launcher" {
  launcher="$REPO_ROOT/scripts/open-design-mcp.sh"

  run jq -e '
    .mcp["open-design"].command == [
      "python3", "scripts/mcp-startup-logger.py", "open-design", "--",
      "bash", "scripts/open-design-mcp.sh"
    ]
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
  [ -x "$launcher" ]
  [ -x "$REPO_ROOT/scripts/hyperframes.sh" ]
  [ -x "$REPO_ROOT/scripts/install-media-tools.sh" ]
  [ -x "$REPO_ROOT/scripts/test-media-tools-live.sh" ]
  [ -x "$REPO_ROOT/scripts/open-design-mcp-smoke.py" ]

  run grep -F 'export COREPACK_ENABLE_DOWNLOAD_PROMPT=0' \
    "$REPO_ROOT/.agents/skills/open-design/scripts/bootstrap.sh"
  [ "$status" -eq 0 ]

  run python3 - "$launcher" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
source_fallback = text.index('if [[ ! -f "$source_cli" ]]; then')
mac_fallback = text.index('if [[ -f "$mac_cli" ]]; then', source_fallback)
health_check = text.index('health_url=', mac_fallback)
assert source_fallback < mac_fallback < health_check
assert 'if [[ "$daemon_only" == true ]]; then' in text[source_fallback:mac_fallback]
PY
  [ "$status" -eq 0 ]
}

@test "OpenDesign waits for daemon health before exposing the MCP bridge" {
  launcher="$REPO_ROOT/scripts/open-design-mcp.sh"

  run python3 - "$launcher" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert "wait_for_health()" in text
assert "OPEN_DESIGN_HEALTH_ATTEMPTS" in text
assert text.index("if ! wait_for_health") < text.index('exec node "$source_cli" mcp')
assert text.index('if [[ "$daemon_only" == true ]]; then') < text.index('exec node "$source_cli" mcp')
PY
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
    'corepack enable --install-directory "$HOME/.local/bin"' \
    'export NEXT_TELEMETRY_DISABLED=1' '${lock_node#\~}' \
    'git fetch --no-tags origin "$lock_commit"'; do
    run grep -F "$required" "$bootstrap"
    [ "$status" -eq 0 ]
  done

  run grep -F "If the current task prohibits subagents, do not call it" "$skill"
  [ "$status" -eq 0 ]

  run python3 - "$bootstrap" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert text.index("git sparse-checkout init --cone") < text.index('git checkout --detach "$lock_commit"')
PY
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
