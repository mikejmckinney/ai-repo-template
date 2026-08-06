#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
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
