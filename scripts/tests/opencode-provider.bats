#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  source "$REPO_ROOT/scripts/workflows/lib/pick-advisory-provider.sh"
  unset CURSOR_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY
  unset ADVISORY_REVIEW_PROVIDER POSTMERGE_RETRO_PROVIDER WEEKLY_REVIEW_PROVIDER
  OPENCODE_BIN=/bin/true
  antigravity_enabled=false
}

@test "auto routing prefers OpenCode when its runtime and credentials are available" {
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run pick_advisory_provider advisory

  [ "$status" -eq 0 ]
  [ "$output" = opencode ]
}

@test "OpenAI API credentials alone do not enable OpenCode in public CI" {
  OPENAI_API_KEY=openai-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  init_advisory_provider_credentials

  run pick_advisory_provider advisory

  [ "$status" -eq 0 ]
  [ "$output" = cursor ]
}

@test "auto routing falls back to Cursor when OpenCode credentials are unavailable" {
  CURSOR_API_KEY=cursor-test
  init_advisory_provider_credentials

  run pick_advisory_provider retro

  [ "$status" -eq 0 ]
  [ "$output" = cursor ]
}

@test "auto routing exposes an ordered cross-provider cascade" {
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run list_advisory_providers retro

  [ "$status" -eq 0 ]
  [ "$output" = $'opencode\ncursor\ngemini' ]
}

@test "full-evidence OpenCode dispatch does not call the bounded pass" {
  run python3 - "$REPO_ROOT/scripts/workflows/postmerge-retro/run-postmerge-retro.sh" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert "opencode) route=full-evidence-opencode" in text
assert 'run_full_evidence_provider "$provider"' in text
assert "validate_provider_output" in text
assert "full-evidence-opencode)\n    run_bounded_pass" not in text
PY

  [ "$status" -eq 0 ]
}

@test "full-evidence OpenCode dispatch records and validates retrieval" {
  run grep -q 'OPENCODE_RETRIEVAL_TRACE_FILE=' \
    "$REPO_ROOT/scripts/workflows/postmerge-retro/run-postmerge-retro.sh"
  [ "$status" -eq 0 ]

  run grep -q 'validate-opencode-retrieval.py' \
    "$REPO_ROOT/scripts/workflows/postmerge-retro/run-postmerge-retro.sh"
  [ "$status" -eq 0 ]
}

@test "OpenCode lifecycle diagnostics records a terminating signal" {
  tmp="$(mktemp -d)"
  cat >"$tmp/mock-opencode" <<'EOF'
#!/usr/bin/env bash
kill -TERM "$$"
EOF
  chmod +x "$tmp/mock-opencode"

  run env \
    OPENCODE_BIN="$tmp/mock-opencode" \
    OPENCODE_DIAG_DIR="$tmp/diag" \
    "$REPO_ROOT/scripts/diagnose-opencode-session.sh"

  [ "$status" -eq 143 ]
  run grep -q 'status=143 signal=15' "$tmp/diag/lifecycle.log"
  [ "$status" -eq 0 ]
  [ -f "$tmp/diag/process.start" ]
  rm -rf "$tmp"
}

@test "OpenCode runner validates text output, retries once, then advances models" {
  tmp="$(mktemp -d)"
  cat >"$tmp/mock-sdk.mjs" <<'EOF'
import { appendFileSync } from "node:fs"

export async function createOpencode(options) {
  if (options.port !== 0) throw new Error("OpenCode server port must be ephemeral")
  return {
    client: {
      session: {
        create: async () => ({ data: { id: "session-test" } }),
        prompt: async (parameters) => {
          if (!parameters.sessionID) throw new Error("sessionID must be flattened")
          if (parameters.format) throw new Error("OpenCode format must not be used")
          const model = `${parameters.model.providerID}/${parameters.model.modelID}`
          appendFileSync(process.env.ATTEMPT_LOG, `${model}\n`)
          if (model === process.env.MOCK_FAIL_MODEL) {
            return { data: { info: { modelID: parameters.model.modelID }, parts: [{ type: "text", text: `invalid ${process.env.OPENAI_API_KEY}` }] } }
          }
          return { data: { info: { modelID: parameters.model.modelID }, parts: [{ type: "text", text: JSON.stringify({ output: `ok:${model}` }) }] } }
        },
        delete: async () => ({ data: true }),
        abort: async () => ({ data: true })
      }
    },
    server: { close() {} }
  }
}

EOF
  printf 'review this' >"$tmp/prompt.md"
  printf '%s\n' '{"type":"object","properties":{"output":{"type":"string"}},"required":["output"],"additionalProperties":false}' >"$tmp/schema.json"
  mkdir -p "$tmp/log"
  {
    printf 'provider diagnostic includes %s\n' 'secret-test-value'
    printf 'timestamp=x message=evaluated permission=read pattern=%s/diff.patch action.permission=read action.action=allow\n' "$tmp"
    printf 'timestamp=x message=evaluated permission=read pattern=README.md action.permission=read action.action=allow\n'
  } >"$tmp/log/2026-07-15T011800.log"

  run env \
    OPENCODE_SDK_MODULE="$tmp/mock-sdk.mjs" \
    OPENCODE_LOG_DIR="$tmp/log" \
    OPENCODE_MODELS="openai/gpt-5.6-sol,openrouter/z-ai/glm-5.2@preset/default" \
    MOCK_FAIL_MODEL="openai/gpt-5.6-sol" \
    ATTEMPT_LOG="$tmp/attempts.log" \
    OPENCODE_RETRIEVAL_TRACE_FILE="$tmp/retrieval-trace.json" \
    OPENAI_API_KEY="secret-test-value" \
    node "$REPO_ROOT/scripts/workflows/lib/run-opencode.mjs" \
    "$tmp/prompt.md" "$tmp/output.txt" "$tmp/schema.json"

  [ "$status" -eq 0 ]
  [ "$(jq -r .output "$tmp/output.txt")" = "ok:openrouter/z-ai/glm-5.2@preset/default" ]
  [ "$(grep -c '^openai/gpt-5.6-sol$' "$tmp/attempts.log")" -eq 2 ]
  [ "$(grep -c '^openrouter/z-ai/glm-5.2@preset/default$' "$tmp/attempts.log")" -eq 1 ]
  [[ "$output" == *'requested_model=openai/gpt-5.6-sol'* ]]
  [[ "$output" == *'requested_model=openrouter/z-ai/glm-5.2@preset/default'* ]]
  [[ "$output" == *'provider diagnostic includes [REDACTED]'* ]]
  [[ "$output" != *'secret-test-value'* ]]
  [ "$(jq -r '.paths | join("|")' "$tmp/retrieval-trace.json")" = "$tmp/diff.patch|README.md" ]
  rm -rf "$tmp"
}

@test "OpenCode defaults to the approved OpenRouter model cascade" {
  tmp="$(mktemp -d)"
  cat >"$tmp/mock-sdk.mjs" <<'EOF'
export async function createOpencode() {
  return {
    client: {
      session: {
        create: async () => ({ data: { id: "session-test" } }),
        prompt: async (parameters) => {
          if (!parameters.sessionID) throw new Error("sessionID must be flattened")
          const model = `${parameters.model.providerID}/${parameters.model.modelID}`
          if (model === "openrouter/z-ai/glm-5.2@preset/default") {
            return { data: { info: { error: { name: "ModelError", data: {} } } } }
          }
          return { data: { info: { modelID: parameters.model.modelID }, parts: [{ type: "text", text: `ok:${model}` }] } }
        },
        delete: async () => ({ data: true })
      }
    },
    server: { close() {} }
  }
}
EOF
  printf 'review this' >"$tmp/prompt.md"

  run env \
    OPENCODE_SDK_MODULE="$tmp/mock-sdk.mjs" \
    node "$REPO_ROOT/scripts/workflows/lib/run-opencode.mjs" \
    "$tmp/prompt.md" "$tmp/output.txt"

  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/output.txt")" = "ok:openrouter/minimax/minimax-m3@preset/default" ]
  [[ "$output" == *'requested_model=openrouter/z-ai/glm-5.2@preset/default'* ]]
  [[ "$output" == *'requested_model=openrouter/minimax/minimax-m3@preset/default'* ]]
  [[ "$output" != *'requested_model=openai/'* ]]
  rm -rf "$tmp"
}

@test "OpenCode runner aligns the Node transport with its outer timeout" {
  run grep -q 'setGlobalDispatcher(new Agent({ headersTimeout: timeoutMs, bodyTimeout: timeoutMs }))' \
    "$REPO_ROOT/scripts/workflows/lib/run-opencode.mjs"
  [ "$status" -eq 0 ]

  run jq -e '.dependencies.undici == "7.28.0"' \
    "$REPO_ROOT/.github/agent-runtime/package.json"
  [ "$status" -eq 0 ]
}

@test "CI configs enforce hosted read-only GitHub MCP and separate review from fix tools" {
  run jq -e '
    .autoupdate == false and
    .share == "disabled" and
    .enabled_providers == ["openrouter"] and
    .permission.edit == "deny" and
    .permission.bash == "deny" and
    .permission.task == "deny" and
    .mcp.github_read.type == "remote" and
    .mcp.github_read.url == "https://api.githubcopilot.com/mcp/" and
    .mcp.github_read.oauth == false and
    .mcp.github_read.headers["X-MCP-Readonly"] == "true" and
    .mcp.github_read.headers["X-MCP-Lockdown"] == "true" and
    .mcp.github_read.headers["X-MCP-Toolsets"] == "repos,issues,pull_requests,actions"
  ' "$REPO_ROOT/.github/agent-runtime/review.json"
  [ "$status" -eq 0 ]

  run jq -e '
    .autoupdate == false and
    .share == "disabled" and
    .enabled_providers == ["openrouter"] and
    .permission.edit == "allow" and
    .permission.task == "deny" and
    .permission.bash == "deny" and
    .mcp.github_read.type == "remote" and
    .mcp.github_read.url == "https://api.githubcopilot.com/mcp/" and
    .mcp.github_read.headers["X-MCP-Readonly"] == "true" and
    .mcp.github_read.headers["X-MCP-Lockdown"] == "true"
  ' "$REPO_ROOT/.github/agent-runtime/fix.json"
  [ "$status" -eq 0 ]
}

@test "CI configs override merged interactive providers and MCP servers" {
  for profile in review fix; do
    run jq --arg profile "$profile" -s -e '
      .[0] as $interactive |
      .[1] as $ci |
      $ci.small_model == "openrouter/z-ai/glm-5.2@preset/default" and
      $ci.agent.build.steps == (if $profile == "review" then 24 else 4 end) and
      all($interactive.mcp | keys[]; $ci.mcp[.].enabled == false)
    ' "$REPO_ROOT/.opencode/opencode.json" "$REPO_ROOT/.github/agent-runtime/$profile.json"
    [ "$status" -eq 0 ]
  done
}

@test "workflows install the locked OpenCode runtime on GitHub-hosted Ubuntu" {
  for workflow in agent-advisory-review agent-postmerge-retro agent-weekly-review; do
    file="$REPO_ROOT/.github/workflows/${workflow}.yml"
    run grep -q 'npm ci --prefix .github/agent-runtime' "$file"
    [ "$status" -eq 0 ]
    run grep -q 'actions/setup-node@v4' "$file"
    [ "$status" -eq 0 ]
    run grep -q 'AGENT_RUNTIME_IMAGE' "$file"
    [ "$status" -ne 0 ]
    run grep -q 'OPENAI_API_KEY' "$file"
    [ "$status" -ne 0 ]
  done

  run grep -q 'npm ci --prefix .github/agent-runtime' \
    "$REPO_ROOT/.github/workflows/ci-tests.yml"
  [ "$status" -eq 0 ]
}

@test "unverified OpenCode fix attempts are discarded before a verified patch is promoted" {
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email test@example.com
  git -C "$tmp" config user.name Test
  printf 'base\n' >"$tmp/result.txt"
  git -C "$tmp" add result.txt
  git -C "$tmp" commit -qm base
  printf 'fix this' >"$tmp/prompt.md"
  cat >"$tmp/mock-runner.mjs" <<'EOF'
import { appendFileSync, writeFileSync } from "node:fs"
const [, , , output] = process.argv
const model = process.env.OPENCODE_MODELS
appendFileSync(process.env.ATTEMPT_LOG, `${model}:${process.cwd()}\n`)
writeFileSync("result.txt", `${model}\n`)
writeFileSync(output, "success\n")
EOF
  cat >"$tmp/verify.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${GITHUB_TOKEN:-}${GH_TOKEN:-}${OPENCODE_GITHUB_TOKEN:-}${OPENAI_API_KEY:-}${OPENROUTER_API_KEY:-}" ]] || {
  for name in GITHUB_TOKEN GH_TOKEN OPENCODE_GITHUB_TOKEN OPENAI_API_KEY OPENROUTER_API_KEY; do
    [[ -z "${!name:-}" ]] || echo "verification inherited $name" >&2
  done
  exit 1
}
actual="$(cat result.txt)"
[[ "$actual" == "openrouter/z-ai/glm-5.2@preset/default" ]] || {
  echo "unexpected result: $actual" >&2
  exit 1
}
EOF
  chmod +x "$tmp/verify.sh"

  run env \
    ATTEMPT_LOG="$tmp/attempts.log" \
    OPENCODE_RUNNER="$tmp/mock-runner.mjs" \
    OPENCODE_FIX_VERIFY_COMMAND="$tmp/verify.sh" \
    OPENCODE_MODELS="openai/gpt-5.6-sol,openrouter/z-ai/glm-5.2@preset/default" \
    OPENAI_API_KEY="openai-secret-test" \
    OPENCODE_GITHUB_TOKEN="github-secret-test" \
    GITHUB_TOKEN="publisher-secret-test" \
    bash "$REPO_ROOT/scripts/workflows/lib/run-opencode-fix.sh" \
    "$tmp/prompt.md" "$tmp/output.txt" "$tmp"

  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/result.txt")" = "openrouter/z-ai/glm-5.2@preset/default" ]
  [ "$(wc -l <"$tmp/attempts.log" | tr -d ' ')" -eq 2 ]
  [ "$(cut -d: -f2- "$tmp/attempts.log" | sort -u | wc -l | tr -d ' ')" -eq 2 ]
  rm -rf "$tmp"
}

@test "truncated retro evidence routes through tool-capable OpenCode" {
  tmp="$(mktemp -d)"
  head -c 5000 /dev/zero | tr '\0' 'a' >"$tmp/diff.patch"
  printf 'noop.txt\n' >"$tmp/changed-files.txt"
  touch "$tmp/noop.txt"

  run env \
    OPENCODE_BIN=/bin/true \
    OPENROUTER_API_KEY=openrouter-test \
    OPENCODE_GITHUB_TOKEN=github-read-test \
    python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/compute-evidence-coverage.py" \
    "$tmp" --pr 7 --diff-limit 1000 --repo-root "$tmp"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"evidence_route": "full-evidence-opencode"'* ]]
  [[ "$output" == *'"provider_resolved": "opencode"'* ]]
  rm -rf "$tmp"
}

@test "OpenAI credentials alone do not route truncated evidence to OpenCode" {
  tmp="$(mktemp -d)"
  head -c 5000 /dev/zero | tr '\0' 'a' >"$tmp/diff.patch"
  printf 'noop.txt\n' >"$tmp/changed-files.txt"
  touch "$tmp/noop.txt"

  run env \
    OPENCODE_BIN=/bin/true \
    OPENAI_API_KEY=openai-test \
    OPENCODE_GITHUB_TOKEN=github-read-test \
    CURSOR_API_KEY=cursor-test \
    python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/compute-evidence-coverage.py" \
    "$tmp" --pr 7 --diff-limit 1000 --repo-root "$tmp"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"evidence_route": "full-evidence-cursor"'* ]]
  [[ "$output" == *'"provider_resolved": "cursor"'* ]]
  rm -rf "$tmp"
}
