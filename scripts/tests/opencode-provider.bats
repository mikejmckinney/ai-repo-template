#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  source "$REPO_ROOT/scripts/workflows/lib/pick-advisory-provider.sh"
  unset CLAUDE_CODE_OAUTH_TOKEN CURSOR_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY
  unset ADVISORY_GITHUB_TOKEN
  unset OPENCODE_AUTH_CONTENT OPENCODE_OAUTH_MIN_TTL_SECONDS OPENCODE_MODELS
  unset ADVISORY_REVIEW_PROVIDER POSTMERGE_RETRO_PROVIDER WEEKLY_REVIEW_PROVIDER
  OPENCODE_BIN=/bin/true
  CLAUDE_BIN=/bin/true
  antigravity_enabled=false
}

valid_opencode_auth() {
  jq -cn --argjson expires "$((($(date +%s) + 7200) * 1000))" '{
    openai: {
      type: "oauth",
      access: "access-test",
      refresh: "ci-refresh-disabled",
      expires: $expires,
      accountId: "account-test"
    }
  }'
}

@test "pre-merge auto routing exposes the exact model-specific cascade" {
  CLAUDE_CODE_OAUTH_TOKEN=claude-test
  OPENCODE_AUTH_CONTENT="$(valid_opencode_auth)"
  OPENCODE_OAUTH_MIN_TTL_SECONDS=3600
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run list_advisory_providers advisory

  [ "$status" -eq 0 ]
  [ "$output" = $'claude\nopencode-sol\ncursor\nopencode-kimi' ]
}

@test "pre-merge auto routing omits only unavailable model candidates" {
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run list_advisory_providers advisory

  [ "$status" -eq 0 ]
  [ "$output" = $'cursor\nopencode-kimi' ]
}

@test "explicit OpenCode preserves its internal Sol then Kimi cascade" {
  ADVISORY_REVIEW_PROVIDER=opencode
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  OPENCODE_AUTH_CONTENT="$(valid_opencode_auth)"
  OPENCODE_OAUTH_MIN_TTL_SECONDS=3600
  init_advisory_provider_credentials

  run list_advisory_providers advisory

  [ "$status" -eq 0 ]
  [ "$output" = opencode ]
  [ "$OPENCODE_MODELS" = "openai/gpt-5.6-sol,openrouter/moonshotai/kimi-k3@preset/consensus" ]
}

@test "model-specific candidates map to stable provider provenance" {
  run advisory_candidate_provider opencode-sol
  [ "$status" -eq 0 ]
  [ "$output" = opencode ]

  run advisory_candidate_provider opencode-kimi
  [ "$status" -eq 0 ]
  [ "$output" = opencode ]

  run advisory_candidate_provider claude
  [ "$status" -eq 0 ]
  [ "$output" = claude ]

  run --separate-stderr advisory_candidate_provider antigravity
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"unknown advisory candidate 'antigravity'"* ]]

  run --separate-stderr advisory_candidate_provider gemini
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"unknown advisory candidate 'gemini'"* ]]
}

@test "pre-merge auto routing prefers Grok over Kimi when Sol is unavailable" {
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run pick_advisory_provider advisory

  [ "$status" -eq 0 ]
  [ "$output" = cursor ]
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

@test "pre-merge auto routing fails clearly when no candidate is available" {
  init_advisory_provider_credentials

  run --separate-stderr pick_advisory_provider advisory

  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"no advisory review provider configured"* ]]
}

@test "pre-merge rejects retired Gemini and Antigravity overrides" {
  init_advisory_provider_credentials

  ADVISORY_REVIEW_PROVIDER=gemini
  run --separate-stderr list_advisory_providers advisory
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"unsupported provider 'gemini' for advisory"* ]]

  ADVISORY_REVIEW_PROVIDER=antigravity
  run --separate-stderr list_advisory_providers advisory
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"unsupported provider 'antigravity' for advisory"* ]]
}

@test "auto routing falls back to Cursor when OpenCode credentials are unavailable" {
  CURSOR_API_KEY=cursor-test
  init_advisory_provider_credentials

  run pick_advisory_provider retro

  [ "$status" -eq 0 ]
  [ "$output" = cursor ]
}

@test "auto routing exposes an ordered cross-provider cascade" {
  CLAUDE_CODE_OAUTH_TOKEN=claude-test
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run list_advisory_providers retro

  [ "$status" -eq 0 ]
  [ "$output" = $'claude\nopencode\ncursor\ngemini' ]
}

@test "Claude advisory override is inherited by daily analysis" {
  ADVISORY_REVIEW_PROVIDER=claude
  CLAUDE_CODE_OAUTH_TOKEN=claude-test
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  init_advisory_provider_credentials

  run list_advisory_providers retro

  [ "$status" -eq 0 ]
  [ "$output" = claude ]
}

@test "daily analysis accepts an explicit Claude provider" {
  POSTMERGE_RETRO_PROVIDER=claude
  CLAUDE_CODE_OAUTH_TOKEN=claude-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  init_advisory_provider_credentials

  run list_advisory_providers retro

  [ "$status" -eq 0 ]
  [ "$output" = claude ]
}

@test "Cursor SDK resolves Grok Medium without fast mode" {
  run node --input-type=module - "$REPO_ROOT/scripts/workflows/lib/cursor-model-config.mjs" <<'EOF'
import assert from "node:assert/strict"
import { pathToFileURL } from "node:url"

const modulePath = pathToFileURL(process.argv[2]).href
const { buildCursorModelConfig, cursorBillingTier } = await import(modulePath)
const catalog = [{
  id: "grok-4.5",
  variants: [
    { params: [{ id: "effort", value: "high" }, { id: "fast", value: "true" }] },
    { params: [{ id: "effort", value: "medium" }, { id: "fast", value: "false" }] },
  ],
}]
const model = await buildCursorModelConfig("cursor-grok-4.5-medium", async () => catalog)
assert.deepEqual(model, {
  id: "grok-4.5",
  params: catalog[0].variants[1].params,
})
assert.equal(cursorBillingTier(model, "grok-4.5"), "grok-4.5-medium")
EOF

  [ "$status" -eq 0 ]
}

@test "Cursor runner resolves the SDK from the canonical runtime module" {
  tmp="$(mktemp -d)"
  printf 'review this' >"$tmp/prompt.md"
  cat >"$tmp/cursor-sdk.mjs" <<'EOF'
export const Cursor = {
  models: {
    list: async () => [{
      id: "grok-4.5",
      variants: [{ params: [{ id: "effort", value: "medium" }, { id: "fast", value: "false" }] }],
    }],
  },
}
export const Agent = {
  prompt: async (_prompt, options) => {
    if (options.mode !== "plan") throw new Error("Cursor advisory must run in plan mode")
    const github = options.mcpServers?.github_read
    if (github?.type !== "http") throw new Error("Cursor advisory omitted GitHub MCP")
    if (github.url !== "https://api.githubcopilot.com/mcp/") throw new Error("Cursor advisory used the wrong GitHub MCP URL")
    if (github.headers?.Authorization !== "Bearer github-read-test") throw new Error("Cursor advisory omitted the read-only token")
    if (github.headers?.["X-MCP-Readonly"] !== "true" || github.headers?.["X-MCP-Lockdown"] !== "true") {
      throw new Error("Cursor advisory omitted GitHub MCP lockdown headers")
    }
    setInterval(() => {}, 1000)
    return { model: { id: "grok-4.5" }, status: "completed", result: "cursor-ok\n" }
  },
}
EOF

  run timeout 3s env CURSOR_API_KEY=cursor-test ADVISORY_GITHUB_TOKEN=github-read-test \
    CURSOR_SDK_MODULE="$tmp/cursor-sdk.mjs" \
    CURSOR_ADVISORY_MODEL=cursor-grok-4.5-medium \
    node "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-cursor.mjs" \
    "$tmp/prompt.md" "$tmp/output.txt"

  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/output.txt")" = cursor-ok ]
  rm -rf "$tmp"
}

@test "Claude runner pins Opus 5 medium and records the observed model" {
  tmp="$(mktemp -d)"
  printf 'review this' >"$tmp/prompt.md"
  cat >"$tmp/schema.json" <<'JSON'
{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"object","properties":{"result":{"$ref":"#/$defs/result"}},"$defs":{"result":{"type":"string"}}}
JSON
  cat >"$tmp/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$CLAUDE_ARGS_FILE"
cat >/dev/null
for ((i = 1; i <= $#; i++)); do
  if [[ "${!i}" == "--mcp-config" ]]; then
    next=$((i + 1))
    cp "${!next}" "$CLAUDE_MCP_CONFIG_CAPTURE"
  fi
done
  jq -cn '{
    is_error: false,
    result: "free-form text is not the advisory contract",
    structured_output: {evidence_retrieved: true, findings: []},
    session_id: "claude-session",
    modelUsage: {
      "claude-haiku-4-5-20251001": {inputTokens: 1, outputTokens: 1},
      "claude-opus-5": {inputTokens: 1, outputTokens: 1}
    }
  }'
EOF
  chmod +x "$tmp/claude"

  run env PATH="$tmp:$PATH" CLAUDE_ARGS_FILE="$tmp/args" \
    CLAUDE_CODE_OAUTH_TOKEN=claude-test \
    ADVISORY_GITHUB_TOKEN=github-read-test \
    CLAUDE_REVIEW_SCHEMA="$tmp/schema.json" \
    CLAUDE_ADVISORY_SESSION_ID=11111111-1111-4111-8111-111111111111 \
    CLAUDE_ADVISORY_SESSION_ID_FILE="$tmp/session-id.txt" \
    CLAUDE_MCP_CONFIG_CAPTURE="$tmp/mcp.json" \
    ADVISORY_PROVIDER_METADATA_FILE="$tmp/metadata.json" \
    "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-claude.sh" \
    "$tmp/prompt.md" "$tmp/output.txt"

  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/output.txt")" = '{"evidence_retrieved":true,"findings":[]}' ]
  grep -q -- '--model claude-opus-5' "$tmp/args"
  grep -q -- '--effort medium' "$tmp/args"
  grep -q -- '--output-format json' "$tmp/args"
  grep -q -- '--json-schema' "$tmp/args"
  grep -q -- 'http://json-schema.org/draft-07/schema#' "$tmp/args"
  grep -q -- '#/\$defs/result' "$tmp/args"
  ! grep -q -- 'draft/2020-12' "$tmp/args"
  grep -q -- '--tools Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__\*' "$tmp/args"
  grep -q -- '--allowedTools Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__\*' "$tmp/args"
  grep -q -- '--strict-mcp-config' "$tmp/args"
  grep -q -- '--mcp-config' "$tmp/args"
  [ "$(grep -c -- '--safe-mode' "$tmp/args")" -eq 0 ]
  grep -q -- '--session-id 11111111-1111-4111-8111-111111111111' "$tmp/args"
  ! grep -q -- '--no-session-persistence' "$tmp/args"
  [ "$(cat "$tmp/session-id.txt")" = 11111111-1111-4111-8111-111111111111 ]
  run jq -e '
    .mcpServers.github_read.type == "http" and
    .mcpServers.github_read.url == "https://api.githubcopilot.com/mcp/" and
    .mcpServers.github_read.headers.Authorization == "Bearer ${ADVISORY_GITHUB_TOKEN}" and
    .mcpServers.github_read.headers["X-MCP-Toolsets"] == "repos,issues,pull_requests,actions" and
    .mcpServers.github_read.headers["X-MCP-Readonly"] == "true" and
    .mcpServers.github_read.headers["X-MCP-Lockdown"] == "true"
  ' "$tmp/mcp.json"
  [ "$status" -eq 0 ]
  grep -q -- '"result"' "$tmp/args"
  [ "$(jq -r '.provider + "/" + .model' "$tmp/metadata.json")" = "claude/claude-opus-5" ]
  [ "$(jq -r .requested_model "$tmp/metadata.json")" = claude-opus-5 ]
  rm -rf "$tmp"
}

@test "Claude advisory failure diagnostics copy the exact persisted session" {
  tmp="$(mktemp -d)"
  session_id=22222222-2222-4222-8222-222222222222
  mkdir -p "$tmp/home/.claude/projects/project-test"
  printf '%s\n' '{"type":"assistant","message":"diagnostic secret-value-test"}' \
    >"$tmp/home/.claude/projects/project-test/${session_id}.jsonl"

  run env HOME="$tmp/home" GITHUB_TOKEN=secret-value-test python3 \
    "$REPO_ROOT/scripts/workflows/advisory-review/collect-claude-session.py" \
    --session-id "$session_id" \
    --output "$tmp/artifacts/${session_id}.jsonl" \
    --redact-env GITHUB_TOKEN

  [ "$status" -eq 0 ]
  grep -q 'diagnostic' "$tmp/artifacts/${session_id}.jsonl"
  grep -q '\[REDACTED:GITHUB_TOKEN\]' "$tmp/artifacts/${session_id}.jsonl"
  ! grep -q 'secret-value-test' "$tmp/artifacts/${session_id}.jsonl"
  rm -rf "$tmp"
}

@test "Claude retrieval extraction records local reads and read-only GitHub MCP calls" {
  tmp="$(mktemp -d)"
  session_id=33333333-3333-4333-8333-333333333333
  mkdir -p "$tmp/home/.claude/projects/project-test" "$tmp/repo/src"
  printf 'source\n' >"$tmp/repo/src/app.py"
  cat >"$tmp/home/.claude/projects/project-test/${session_id}.jsonl" <<JSONL
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"$tmp/repo/src/app.py"}},{"type":"tool_use","name":"Grep","input":{"pattern":"source","path":"$tmp/repo/src"}},{"type":"tool_use","name":"Grep","input":{"pattern":"source"}},{"type":"tool_use","name":"Glob","input":{"pattern":"src/**/*.py"}},{"type":"tool_use","name":"mcp__github_read__get_pull_request","input":{"owner":"owner","repo":"repo","pull_number":1}}]}}
JSONL

  run env HOME="$tmp/home" python3 \
    "$REPO_ROOT/scripts/workflows/lib/extract-claude-retrieval.py" \
    --session-id "$session_id" --repo-root "$tmp/repo" \
    --output "$tmp/retrieval-trace.json"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.paths[0]' "$tmp/retrieval-trace.json")" = "$tmp/repo/src/app.py" ]
  [ "$(jq -r '.paths | length' "$tmp/retrieval-trace.json")" -eq 1 ]
  [ "$(jq -r '.directories | join("|")' "$tmp/retrieval-trace.json")" = "$tmp/repo/src|$tmp/repo" ]
  [ "$(jq -r '.github_calls' "$tmp/retrieval-trace.json")" -eq 1 ]
  [ "$(jq -r '.tools | join("|")' "$tmp/retrieval-trace.json")" = "Read|Grep|Glob|mcp__github_read__get_pull_request" ]
  rm -rf "$tmp"
}

@test "Claude retrieval extraction defaults null Grep paths without counting Glob" {
  tmp="$(mktemp -d)"
  session_id=44444444-4444-4444-8444-444444444444
  mkdir -p "$tmp/home/.claude/projects/project-test" "$tmp/repo/src"
  cat >"$tmp/home/.claude/projects/project-test/${session_id}.jsonl" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Grep","input":{"pattern":"source","path":null}},{"type":"tool_use","name":"Glob","input":{"pattern":"src/**/*.py"}}]}}
JSONL

  run env HOME="$tmp/home" python3 \
    "$REPO_ROOT/scripts/workflows/lib/extract-claude-retrieval.py" \
    --session-id "$session_id" --repo-root "$tmp/repo" \
    --output "$tmp/retrieval-trace.json"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.directories | join("|")' "$tmp/retrieval-trace.json")" = "$tmp/repo" ]
  [ "$(jq -r '.paths | length' "$tmp/retrieval-trace.json")" -eq 0 ]
  rm -rf "$tmp"
}

@test "advisory workflow uploads failure-only Claude sessions for seven days" {
  workflow="$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
  runner="$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh"

  grep -q 'actions/upload-artifact@v4' "$workflow"
  grep -q 'path: .artifacts/advisory-claude-session/' "$workflow"
  grep -q 'retention-days: 7' "$workflow"
  grep -q 'claude-session-diagnostics.sh' "$runner"
  grep -q 'collect-claude-session.py' \
    "$REPO_ROOT/scripts/workflows/lib/claude-session-diagnostics.sh"
}

@test "pre-merge advisory prompt is retrieval-first and injects no source bodies" {
  runner="$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh"
  prompt="$REPO_ROOT/.github/prompts/pr-advisory-review.md"

  ! grep -q 'prompt_helpers.py.*select-context' "$runner"
  ! grep -q 'Repo startup context (automation-supplied' "$runner"
  ! grep -q 'printf.*pr_body' "$runner"
  ! grep -q 'printf.*diff_text' "$runner"
  ! grep -q 'Existing advisory snapshot (dedupe against this)' "$runner"
  grep -q 'Retrieve the current issue, pull request, discussion, checks, and diff' "$prompt"
  grep -q 'Review only changes between the diff base and expected head' "$prompt"
  grep -q 'Expected head SHA' "$runner"
}

@test "Claude advisory schema requires every normalized triage field" {
  schema="$REPO_ROOT/.github/schemas/advisory-review.schema.json"

  run jq -e '
    (.required | index("evidence_retrieved")) != null and
    ((.properties.findings.items.required | index("regression_guard")) != null)
  ' "$schema"

  [ "$status" -eq 0 ]
}

@test "advisory provider commands honor the candidate timeout" {
  run env ADVISORY_CANDIDATE_TIMEOUT_SECONDS=1 CLAUDE_CODE_OAUTH_TOKEN=claude-test \
    bash -c '
      source "$1"
      run_with_provider_credentials claude bash -c "sleep 2"
    ' _ "$REPO_ROOT/scripts/workflows/lib/invoke-advisory-llm.sh"

  [ "$status" -eq 124 ]
}

@test "advisory candidate timeout defaults to 300 seconds" {
  grep -q "ADVISORY_CANDIDATE_TIMEOUT_SECONDS || '300'" \
    "$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
  grep -q 'parse_positive_int ADVISORY_CANDIDATE_TIMEOUT_SECONDS 300' \
    "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh"
  grep -q 'ADVISORY_CANDIDATE_TIMEOUT_SECONDS' "$REPO_ROOT/docs/guides/agent-pipeline.md"
  grep -q '`300` seconds' "$REPO_ROOT/docs/guides/agent-pipeline.md"
}

@test "workflow positive integers use one decimal-safe parser" {
  helper="$REPO_ROOT/scripts/workflows/lib/parse-positive-int.sh"
  [ -f "$helper" ]

  run bash -c 'source "$1"; parse_positive_int TEST_VALUE 9 08' _ "$helper"
  [ "$status" -eq 0 ]
  [ "$output" = 8 ]

  for script in \
    scripts/workflows/advisory-review/run-advisory-review.sh \
    scripts/workflows/postmerge-retro/assemble-retro-prompt.sh \
    scripts/workflows/postmerge-retro/run-postmerge-retro.sh \
    scripts/workflows/postmerge-retro/run-postmerge-retro-monolithic.sh \
    scripts/workflows/weekly-review/run-weekly-review-scan.sh; do
    grep -q 'source "$LIB_DIR/parse-positive-int.sh"' "$REPO_ROOT/$script"
    ! grep -q '^parse_positive_int()' "$REPO_ROOT/$script"
  done
}

@test "advisory candidate timeout terminates descendant processes" {
  tmp="$(mktemp -d)"
  cat >"$tmp/candidate.sh" <<'EOF'
#!/usr/bin/env bash
bash -c 'trap '\''touch "$DESCENDANT_TERM_MARKER"; exit 0'\'' TERM; while :; do sleep 1; done' \
  </dev/null >/dev/null 2>&1 &
echo "$!" >"$DESCENDANT_PID_FILE"
wait
EOF
  chmod +x "$tmp/candidate.sh"

  run env ADVISORY_CANDIDATE_TIMEOUT_SECONDS=1 CLAUDE_CODE_OAUTH_TOKEN=claude-test \
    DESCENDANT_TERM_MARKER="$tmp/terminated" DESCENDANT_PID_FILE="$tmp/pid" \
    bash -c '
      source "$1"
      run_with_provider_credentials claude "$2"
    ' _ "$REPO_ROOT/scripts/workflows/lib/invoke-advisory-llm.sh" "$tmp/candidate.sh"

  run_status="$status"
  for _ in {1..20}; do
    [ -e "$tmp/terminated" ] && break
    sleep 0.1
  done
  terminated=0
  [ -e "$tmp/terminated" ] && terminated=1
  if [ -s "$tmp/pid" ]; then
    descendant_pid="$(cat "$tmp/pid")"
    pkill -TERM -P "$descendant_pid" 2>/dev/null || true
    kill "$descendant_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"

  [ "$run_status" -eq 124 ]
  [ "$terminated" -eq 1 ]
}

@test "Claude runner rejects output without observed model usage" {
  tmp="$(mktemp -d)"
  printf 'review this' >"$tmp/prompt.md"
  cat >"$tmp/claude" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
jq -cn '{
  is_error: false,
  result: "claude-ok",
  structured_output: {findings: []},
  session_id: "claude-session",
  modelUsage: {"claude-haiku-4-5-20251001": {inputTokens: 1, outputTokens: 1}}
}'
EOF
  chmod +x "$tmp/claude"

  run env PATH="$tmp:$PATH" CLAUDE_CODE_OAUTH_TOKEN=claude-test \
    ADVISORY_GITHUB_TOKEN=github-read-test \
    ADVISORY_PROVIDER_METADATA_FILE="$tmp/metadata.json" \
    "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-claude.sh" \
    "$tmp/prompt.md" "$tmp/output.txt"

  [ "$status" -eq 1 ]
  [[ "$output" == *"omitted observed model usage"* ]]
  [ ! -e "$tmp/metadata.json" ]
  rm -rf "$tmp"
}

@test "model-specific OpenCode dispatch pins one model per attempt" {
  run bash -c '
    source "$1"
    run_with_provider_credentials() { printf "%s\n" "$*"; }
    invoke_advisory_llm prompt output opencode-sol advisory repo workdir lib
    invoke_advisory_llm prompt output opencode-kimi advisory repo workdir lib
  ' _ "$REPO_ROOT/scripts/workflows/lib/invoke-advisory-llm.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"OPENCODE_MODELS=openai/gpt-5.6-sol"* ]]
  [[ "$output" == *"OPENCODE_VARIANT=medium"* ]]
  [ "$(grep -c 'OPENCODE_VARIANT=medium' <<<"$output")" -eq 1 ]
  [[ "$output" == *"OPENCODE_MODELS=openrouter/moonshotai/kimi-k3@preset/consensus"* ]]
  [[ "$output" != *"OPENCODE_MODELS=openai/gpt-5.6-sol,openrouter/"* ]]
}

@test "hosted workflows export both locked SDK modules" {
  for workflow in agent-advisory-review.yml agent-postmerge-retro.yml agent-weekly-review.yml; do
    grep -q 'sudo apt-get install -y -qq.*ripgrep' "$REPO_ROOT/.github/workflows/$workflow"
    grep -q 'OPENCODE_SDK_MODULE=.*@opencode-ai/sdk' "$REPO_ROOT/.github/workflows/$workflow"
    grep -q 'CURSOR_SDK_MODULE=.*@cursor/sdk/dist/esm/index.js' "$REPO_ROOT/.github/workflows/$workflow"
  done
  run jq -e '.dependencies["@cursor/sdk"] == "1.0.24"' \
    "$REPO_ROOT/.github/agent-runtime/package.json"

  [ "$status" -eq 0 ]
}

@test "Cursor runners fall back to the canonical runtime without workflow exports" {
  for runner in \
    scripts/workflows/advisory-review/run-advisory-cursor.mjs \
    scripts/workflows/postmerge-retro/run-postmerge-retro-full-cursor.mjs; do
    grep -q '.github/agent-runtime/node_modules/@cursor/sdk/dist/esm/index.js' \
      "$REPO_ROOT/$runner"
  done
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
            const oauthAccess = JSON.parse(process.env.OPENCODE_AUTH_CONTENT).openai.access
            return { data: { info: { modelID: parameters.model.modelID }, parts: [{ type: "text", text: `invalid ${process.env.OPENAI_API_KEY} ${oauthAccess}` }] } }
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
    ADVISORY_PROVIDER_METADATA_FILE="$tmp/provider-metadata.json" \
    OPENCODE_AUTH_CONTENT='{"openai":{"access":"oauth-access-secret"}}' \
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
  [[ "$output" != *'oauth-access-secret'* ]]
  [ "$(jq -r '.paths | join("|")' "$tmp/retrieval-trace.json")" = "$tmp/diff.patch|README.md" ]
  [ "$(jq -r '.provider + "/" + .model' "$tmp/provider-metadata.json")" = \
    "opencode/openrouter/z-ai/glm-5.2@preset/default" ]
  rm -rf "$tmp"
}

@test "OpenCode defaults to the approved Kimi model" {
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
  [ "$(cat "$tmp/output.txt")" = "ok:openrouter/moonshotai/kimi-k3@preset/consensus" ]
  [[ "$output" == *'requested_model=openrouter/moonshotai/kimi-k3@preset/consensus'* ]]
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

@test "pinned OpenCode SDK and CLI accept model variants" {
  run python3 - \
    "$REPO_ROOT/.github/agent-runtime/node_modules/@opencode-ai/sdk/dist/v2/gen/sdk.gen.d.ts" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
signature = text.split("prompt<ThrowOnError", 1)[1].split("deleteMessage<ThrowOnError", 1)[0]
assert "variant?: string;" in signature
PY
  [ "$status" -eq 0 ]

  run "$REPO_ROOT/.github/agent-runtime/node_modules/.bin/opencode" run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'--variant'* ]]
}

@test "OpenCode runner corrects model-authored priority bands" {
  tmp="$(mktemp -d)"
  cat >"$tmp/mock-sdk.mjs" <<'EOF'
import { appendFileSync, readFileSync } from "node:fs"

export async function createOpencode() {
  return {
    client: {
      session: {
        create: async () => ({ data: { id: "session-test" } }),
        prompt: async (parameters) => {
          appendFileSync(process.env.ATTEMPT_LOG, "attempt\n")
          const attempts = readFileSync(process.env.ATTEMPT_LOG, "utf8").trim().split("\n").length
          const issue = {
            title: "Finding",
            body: "Body",
            dedupe_key: "finding",
            repro_steps: ["Reproduce"],
            triage_version: 2,
            impact: "incorrect-behavior",
            impact_magnitude: "material",
            trigger_likelihood: "common",
            affected_scope: "broad",
            reversibility: "hard",
            fix_cost: "trivial",
            confidence: "high",
            uncertainty: "none",
            ...(attempts === 1 ? { priority_band: "fix-now" } : {})
          }
          return {
            data: {
              info: { modelID: parameters.model.modelID },
              parts: [{
                type: "text",
                text: JSON.stringify({
                  pr: 1,
                  summary: "Summary",
                  evidence_complete: true,
                  follow_up_issues: [issue]
                })
              }]
            }
          }
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
    OPENCODE_MODELS="openrouter/test-model" \
    ATTEMPT_LOG="$tmp/attempts.log" \
    node "$REPO_ROOT/scripts/workflows/lib/run-opencode.mjs" \
    "$tmp/prompt.md" "$tmp/output.json" \
    "$REPO_ROOT/.github/schemas/postmerge-retro.schema.json"

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$tmp/attempts.log" | tr -d ' ')" -eq 2 ]
  [ "$(jq 'any(.follow_up_issues[]; has("priority_band"))' "$tmp/output.json")" = false ]
  rm -rf "$tmp"
}

@test "CI configs enforce hosted read-only GitHub MCP and separate review from fix tools" {
  run jq -e '
    .autoupdate == false and
    .share == "disabled" and
    .enabled_providers == ["openai", "openrouter"] and
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
    .enabled_providers == ["openai", "openrouter"] and
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
      $ci.small_model == "openrouter/moonshotai/kimi-k3@preset/consensus" and
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
import { appendFileSync, existsSync, writeFileSync } from "node:fs"
const [, , , output] = process.argv
const model = process.env.OPENCODE_MODELS
if (process.env.FIX_PROVIDER_BATCH_JSON && !process.env.FIX_PROVIDER_BATCH_JSON.endsWith("/.artifacts/postmerge-retro/daily-test/daily-retro.json")) process.exit(4)
if (process.env.FIX_PROVIDER_BATCH_JSON && !process.env.FIX_PROVIDER_BATCH_JSON.startsWith(process.cwd())) process.exit(5)
if (process.env.FIX_PROVIDER_BATCH_JSON && !existsSync(process.env.FIX_PROVIDER_BATCH_JSON)) process.exit(6)
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
  mkdir -p "$tmp/.artifacts/postmerge-retro/daily-test"
  printf '{}\n' >"$tmp/.artifacts/postmerge-retro/daily-test/daily-retro.json"

  run env \
    ATTEMPT_LOG="$tmp/attempts.log" \
    OPENCODE_RUNNER="$tmp/mock-runner.mjs" \
    OPENCODE_FIX_VERIFY_COMMAND="$tmp/verify.sh" \
    OPENCODE_MODELS="openai/gpt-5.6-sol,openrouter/z-ai/glm-5.2@preset/default" \
    OPENAI_API_KEY="openai-secret-test" \
    OPENCODE_GITHUB_TOKEN="github-secret-test" \
    GITHUB_TOKEN="publisher-secret-test" \
    FIX_PROVIDER_BATCH_JSON="$tmp/.artifacts/postmerge-retro/daily-test/daily-retro.json" \
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
