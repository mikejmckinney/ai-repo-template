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
  OPENAI_API_KEY=openai-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run pick_advisory_provider advisory

  [ "$status" -eq 0 ]
  [ "$output" = opencode ]
}

@test "auto routing falls back to Cursor when OpenCode credentials are unavailable" {
  CURSOR_API_KEY=cursor-test
  init_advisory_provider_credentials

  run pick_advisory_provider retro

  [ "$status" -eq 0 ]
  [ "$output" = cursor ]
}

@test "OpenCode runner retries structured output once then advances models" {
  tmp="$(mktemp -d)"
  cat >"$tmp/mock-sdk.mjs" <<'EOF'
export async function createOpencode(options) {
  if (options.port !== 0) throw new Error("OpenCode server port must be ephemeral")
  return {
    client: {
      session: {
        create: async () => ({ data: { id: "session-test" } }),
        prompt: async ({ body }) => {
          if (body.format?.retryCount !== 1) throw new Error("retryCount must be 1")
          const model = `${body.model.providerID}/${body.model.modelID}`
          if (model === process.env.MOCK_FAIL_MODEL) {
            return { data: { info: { modelID: body.model.modelID, error: { name: "StructuredOutputError", data: { message: `invalid ${process.env.OPENAI_API_KEY}`, retries: 1 } } } } }
          }
          return { data: { info: { modelID: body.model.modelID, structured: { output: `ok:${model}` } } } }
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

  run env \
    OPENCODE_SDK_MODULE="$tmp/mock-sdk.mjs" \
    OPENCODE_MODELS="openai/gpt-5.6-sol,openrouter/z-ai/glm-5.2@preset/default" \
    MOCK_FAIL_MODEL="openai/gpt-5.6-sol" \
    OPENAI_API_KEY="secret-test-value" \
    node "$REPO_ROOT/scripts/workflows/lib/run-opencode.mjs" \
      "$tmp/prompt.md" "$tmp/output.txt"

  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/output.txt")" = "ok:openrouter/z-ai/glm-5.2@preset/default" ]
  [[ "$output" == *'requested_model=openai/gpt-5.6-sol'* ]]
  [[ "$output" == *'requested_model=openrouter/z-ai/glm-5.2@preset/default'* ]]
  [[ "$output" != *'secret-test-value'* ]]
  rm -rf "$tmp"
}

@test "CI configs enforce hosted read-only GitHub MCP and separate review from fix tools" {
  run jq -e '
    .autoupdate == false and
    .share == "disabled" and
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

@test "workflows install the locked OpenCode runtime on GitHub-hosted Ubuntu" {
  for workflow in agent-advisory-review agent-postmerge-retro agent-weekly-review; do
    file="$REPO_ROOT/.github/workflows/${workflow}.yml"
    run grep -q 'npm ci --prefix .github/agent-runtime' "$file"
    [ "$status" -eq 0 ]
    run grep -q 'actions/setup-node@v4' "$file"
    [ "$status" -eq 0 ]
    run grep -q 'AGENT_RUNTIME_IMAGE' "$file"
    [ "$status" -ne 0 ]
  done
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
    OPENAI_API_KEY=openai-test \
    OPENCODE_GITHUB_TOKEN=github-read-test \
    python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/compute-evidence-coverage.py" \
      "$tmp" --pr 7 --diff-limit 1000 --repo-root "$tmp"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"evidence_route": "full-evidence-opencode"'* ]]
  [[ "$output" == *'"provider_resolved": "opencode"'* ]]
  rm -rf "$tmp"
}
