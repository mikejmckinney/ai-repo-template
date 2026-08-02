#!/usr/bin/env bash
# scripts/checks/049-advisory-review-invariants.sh — PR 2 advisory review wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking advisory review invariants..."

  ADVISORY_WORKFLOW=".github/workflows/agent-advisory-review.yml"
  ADVISORY_PROMPT=".github/prompts/pr-advisory-review.md"
  ADVISORY_DIR="scripts/workflows/advisory-review"
  UPSERT_SCRIPT="${ADVISORY_DIR}/upsert-pr-comment.sh"
  RUN_SCRIPT="${ADVISORY_DIR}/run-advisory-review.sh"
  GEMINI_SCRIPT="${ADVISORY_DIR}/run-advisory-gemini.py"
  CURSOR_SCRIPT="${ADVISORY_DIR}/run-advisory-cursor.mjs"
  CLAUDE_SCRIPT="${ADVISORY_DIR}/run-advisory-claude.sh"
  CLAUDE_SESSION_COLLECTOR="${ADVISORY_DIR}/collect-claude-session.py"
  CLAUDE_RUNNER="scripts/workflows/lib/run-claude-review.sh"
  CLAUDE_DIAGNOSTICS="scripts/workflows/lib/claude-session-diagnostics.sh"
  CLAUDE_TRACE_EXTRACTOR="scripts/workflows/lib/extract-claude-retrieval.py"
  POSTMERGE_WORKFLOW=".github/workflows/agent-postmerge-retro.yml"
  WEEKLY_WORKFLOW=".github/workflows/agent-weekly-review.yml"
  POSTMERGE_CLAUDE_RUNNER="scripts/workflows/postmerge-retro/run-postmerge-retro.sh"
  WEEKLY_CLAUDE_RUNNER="scripts/workflows/weekly-review/run-weekly-review-scan.sh"
  WEEKLY_CLAUDE_VALIDATOR="scripts/workflows/weekly-review/validate-claude-retrieval.py"
  NORMALIZE_SCRIPT="${ADVISORY_DIR}/normalize-advisory-snapshot.py"
  RANGE_SCRIPT="${ADVISORY_DIR}/select-advisory-range.py"
  OPENCODE_RUNNER="scripts/workflows/lib/run-opencode.mjs"
  OPENCODE_FIX_RUNNER="scripts/workflows/lib/run-opencode-fix.sh"
  OPENCODE_REVIEW_CONFIG=".github/agent-runtime/review.json"
  OPENCODE_FIX_CONFIG=".github/agent-runtime/fix.json"
  ADVISORY_TEST="scripts/tests/advisory-snapshot-memory.bats"
  LABELS_SCRIPT="scripts/setup/40-ensure-labels.sh"
  MARKER='ai-advisory-review:v1'

  for f in "$ADVISORY_WORKFLOW" "$ADVISORY_PROMPT" "$UPSERT_SCRIPT" "$RUN_SCRIPT" \
    "$GEMINI_SCRIPT" "$CURSOR_SCRIPT" "$CLAUDE_SCRIPT" "$CLAUDE_SESSION_COLLECTOR" \
    "$CLAUDE_RUNNER" "$CLAUDE_DIAGNOSTICS" "$CLAUDE_TRACE_EXTRACTOR" \
    "$POSTMERGE_WORKFLOW" "$WEEKLY_WORKFLOW" "$POSTMERGE_CLAUDE_RUNNER" \
    "$WEEKLY_CLAUDE_RUNNER" "$WEEKLY_CLAUDE_VALIDATOR" "$NORMALIZE_SCRIPT" \
    "$RANGE_SCRIPT" "$OPENCODE_RUNNER" \
    "$OPENCODE_FIX_RUNNER" "$OPENCODE_REVIEW_CONFIG" "$OPENCODE_FIX_CONFIG"; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (advisory review)"
    fi
  done

  if grep -q 'npm ci --prefix .github/agent-runtime' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q 'OPENCODE_GITHUB_TOKEN' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q 'opencode' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q '@opencode-ai/sdk/v2' "$OPENCODE_RUNNER" 2>/dev/null \
    && grep -q 'api.githubcopilot.com/mcp' "$OPENCODE_REVIEW_CONFIG" 2>/dev/null \
    && grep -q 'X-MCP-Readonly' "$OPENCODE_REVIEW_CONFIG" 2>/dev/null \
    && grep -q 'X-MCP-Lockdown' "$OPENCODE_REVIEW_CONFIG" 2>/dev/null; then
    pass "advisory installs pinned OpenCode SDK on Ubuntu with hosted read-only GitHub MCP"
  else
    fail "advisory missing locked OpenCode install, dedicated token, or hosted MCP security boundary"
  fi

  if grep -q -- '--session-id' "$CLAUDE_RUNNER" 2>/dev/null \
    && ! grep -q -- '--no-session-persistence' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q 'claude-session-diagnostics.sh' "$RUN_SCRIPT" 2>/dev/null \
    && grep -q 'collect-claude-session.py' "$CLAUDE_DIAGNOSTICS" 2>/dev/null \
    && grep -q 'actions/upload-artifact@v4' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q 'path: .artifacts/advisory-claude-session/' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q 'retention-days: 7' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "failed Claude advisory sessions upload as seven-day diagnostics"
  else
    fail "Claude advisory failure diagnostics are not persisted and uploaded"
  fi

  if [[ -f .github/scripts/run-advisory-review.sh ]] \
    || compgen -G ".github/scripts/run-advisory-*" >/dev/null 2>&1; then
    fail "legacy advisory scripts still present under .github/scripts; use ${ADVISORY_DIR}/"
  else
    pass "advisory scripts not duplicated under .github/scripts (AP8)"
  fi

  if grep -q 'ai-review:live' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "advisory workflow is label-gated by ai-review:live"
  else
    fail "advisory workflow missing ai-review:live gate"
  fi

  if grep -q 'pull-requests: write' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "advisory workflow grants pull-requests: write for PR comment API"
  else
    fail "advisory workflow missing pull-requests: write (PR comment POST 403 risk)"
  fi

  if grep -q 'scripts/workflows/advisory-review/run-advisory-review.sh' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "workflow invokes scripts/workflows/advisory-review (AP8)"
  else
    fail "workflow must invoke scripts/workflows/advisory-review/run-advisory-review.sh"
  fi

  if ! grep -q 'ADVISORY_ANTIGRAVITY_ENABLED\|GEMINI_ADVISORY_MODEL\|GEMINI_API_KEY\|GOOGLE_API_KEY' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "pre-merge workflow omits retired Gemini and Antigravity providers"
  else
    fail "pre-merge workflow still exposes Gemini or Antigravity"
  fi

  if grep -q "$MARKER" "$NORMALIZE_SCRIPT" 2>/dev/null \
    && grep -q 'triage_version' "$ADVISORY_PROMPT" 2>/dev/null \
    && ! grep -q 'Severity' "$ADVISORY_PROMPT" 2>/dev/null; then
    pass "advisory automation owns the sticky marker and structured AP11 contract"
  else
    fail "advisory normalization/prompt missing marker ownership or structured AP11 contract"
  fi

  if grep -q 'ai-advisory-memory:v1' "$NORMALIZE_SCRIPT" 2>/dev/null \
    && grep -q 'select-advisory-range.py' "$RUN_SCRIPT" 2>/dev/null \
    && grep -q 'normalize-advisory-snapshot.py' "$RUN_SCRIPT" 2>/dev/null \
    && grep -q 'No findings identified at this head' "$NORMALIZE_SCRIPT" 2>/dev/null; then
    pass "advisory snapshot has provider-neutral memory and explicit no-findings output"
  else
    fail "advisory snapshot missing memory, normalization, or explicit no-findings wiring"
  fi

  if grep -q 'ADVISORY_PROVIDER_METADATA_FILE' "$OPENCODE_RUNNER" 2>/dev/null \
    && grep -q 'ADVISORY_PROVIDER_METADATA_FILE' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'ADVISORY_PROVIDER_METADATA_FILE' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q 'ADVISORY_PROVIDER_METADATA_FILE' "$GEMINI_SCRIPT" 2>/dev/null; then
    pass "retained analysis providers record automation-owned model metadata"
  else
    fail "one or more advisory providers omit model metadata"
  fi

  if grep -q '@anthropic-ai/claude-code@2.1.220' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q "if: env.CLAUDE_CANDIDATE == 'true'" "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q 'CLAUDE_CODE_OAUTH_TOKEN:.*secrets.CLAUDE_OAUTH_SECRET' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q -- '--json-schema' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q -- '--model "$requested_model"' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q -- '--effort medium' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q -- '--tools "Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__\*"' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q -- '--allowedTools "Read,Glob,Grep,WebFetch,WebSearch,mcp__github_read__\*"' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q -- '--strict-mcp-config' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q 'X-MCP-Readonly' "$CLAUDE_RUNNER" 2>/dev/null \
    && grep -q 'X-MCP-Lockdown' "$CLAUDE_RUNNER" 2>/dev/null; then
    pass "pre-merge advisory pins Claude Opus 5 Medium with strict read-only GitHub MCP"
  else
    fail "pre-merge advisory missing pinned Claude Code, scoped OAuth, model, effort, or review tools"
  fi

  if grep -q '@anthropic-ai/claude-code@2.1.220' "$POSTMERGE_WORKFLOW" 2>/dev/null \
    && grep -q '@anthropic-ai/claude-code@2.1.220' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'CLAUDE_CODE_OAUTH_TOKEN:.*secrets.CLAUDE_OAUTH_SECRET' "$POSTMERGE_WORKFLOW" 2>/dev/null \
    && grep -q 'CLAUDE_CODE_OAUTH_TOKEN:.*secrets.CLAUDE_OAUTH_SECRET' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'path: .artifacts/postmerge-claude-session/' "$POSTMERGE_WORKFLOW" 2>/dev/null \
    && grep -q 'path: .artifacts/weekly-claude-session/' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && ! grep -q 'path: .artifacts/postmerge-retro/claude-session/' "$POSTMERGE_WORKFLOW" 2>/dev/null \
    && ! grep -q 'path: .artifacts/weekly-review/claude-session/' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'retention-days: 7' "$POSTMERGE_WORKFLOW" 2>/dev/null \
    && grep -q 'retention-days: 7' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'ADVISORY_CANDIDATE_TIMEOUT_SECONDS=' "$POSTMERGE_CLAUDE_RUNNER" 2>/dev/null \
    && grep -q 'WEEKLY_REVIEW_PROVIDER_TIMEOUT_SECONDS' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'ADVISORY_CANDIDATE_TIMEOUT_SECONDS=' "$WEEKLY_CLAUDE_RUNNER" 2>/dev/null \
    && grep -q 'full-evidence-claude' scripts/workflows/postmerge-retro/run-postmerge-retro.sh 2>/dev/null \
    && grep -q 'validate-claude-retrieval.py' scripts/workflows/weekly-review/run-weekly-review-scan.sh 2>/dev/null; then
    pass "daily and weekly analysis reuse Claude with cadence-specific retrieval validation and diagnostics"
  else
    fail "recurring Claude analysis is missing pinned runtime, scoped OAuth, retrieval validation, or diagnostics"
  fi

  if grep -q 'mcpServers' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'github_read' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'X-MCP-Readonly' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'X-MCP-Lockdown' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'mode: "plan"' "$CURSOR_SCRIPT" 2>/dev/null; then
    pass "pre-merge Cursor uses plan mode and the locked-down read-only GitHub MCP"
  else
    fail "pre-merge Cursor missing plan mode or read-only GitHub MCP"
  fi

  if ! grep -q 'prompt_helpers.py.*select-context\|Repo startup context (automation-supplied\|printf.*pr_body\|printf.*diff_text' "$RUN_SCRIPT" 2>/dev/null \
    && grep -q 'Invocation coordinates' "$RUN_SCRIPT" 2>/dev/null \
    && grep -q 'Retrieve the current issue, pull request, discussion, checks, and diff' "$ADVISORY_PROMPT" 2>/dev/null \
    && grep -q 'INJECTED-PR-BODY-SENTINEL' "$ADVISORY_TEST" 2>/dev/null \
    && grep -q 'ADVISORY_TEST_PROMPT_CAPTURE' "$ADVISORY_TEST" 2>/dev/null; then
    pass "pre-merge advisory retrieves source evidence and tests generated prompts for copied bodies"
  else
    fail "pre-merge advisory lacks direct-retrieval instructions or generated-prompt regression coverage"
  fi

  if jq -e '(.required | index("evidence_retrieved")) != null' ".github/schemas/advisory-review.schema.json" >/dev/null 2>&1 \
    && grep -q 'evidence_retrieved must be true' "$NORMALIZE_SCRIPT" 2>/dev/null; then
    pass "advisory retrieval failure advances the provider cascade without reviewed-head memory"
  else
    fail "advisory output contract cannot distinguish completed retrieval from an empty review"
  fi

  if jq -e '
    .permission.webfetch == "allow" and
    .permission.websearch == "allow" and
    .permission.bash == "deny" and
    .permission.edit == "deny" and
    .permission.external_directory == "deny"
  ' "$OPENCODE_REVIEW_CONFIG" >/dev/null 2>&1 \
    && jq -e '
      .permission.webfetch == "deny" and
      .permission.websearch == "deny"
    ' "$OPENCODE_FIX_CONFIG" >/dev/null 2>&1; then
    pass "OpenCode review profile can research the web while its fix profile remains offline"
  else
    fail "OpenCode review/fix internet permissions do not preserve the review-only boundary"
  fi

  if ! grep -q 'Session handshake' "$ADVISORY_PROMPT" 2>/dev/null; then
    pass "advisory prompt omits the retired session handshake"
  else
    fail "advisory prompt still requires the retired session handshake"
  fi

  if grep -q '^ai-review:live|' "$LABELS_SCRIPT" 2>/dev/null; then
    pass "ai-review:live declared in label setup"
  else
    fail "ai-review:live missing from $LABELS_SCRIPT"
  fi

  if grep -q 'cancel-in-progress: true' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && ! grep -q 'review:blocking-ai' "$ADVISORY_PROMPT" 2>/dev/null \
    && ! grep -q 'implementation-complete' "$ADVISORY_PROMPT" 2>/dev/null; then
    pass "advisory review is parallel, replaceable, and independent of completion gates"
  else
    fail "advisory review must remain non-blocking and independent of completion gates"
  fi

  if grep -qF -- '-F body=@' "$UPSERT_SCRIPT" 2>/dev/null \
    && ! grep -qF -- '-f body=@' "$UPSERT_SCRIPT" 2>/dev/null; then
    pass "upsert-pr-comment uses gh api -F body=@ (not -f, which posts literal @path)"
  else
    fail "upsert-pr-comment.sh must use -F body=@ for file-loaded comment bodies"
  fi

  if grep -q 'DEFAULT_CURSOR_MODEL' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'cursorBillingTier' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'GITHUB_RUN_ID' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'buildCursorModelConfig' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'cursor-grok-4.5-medium' "scripts/workflows/lib/cursor-model-config.mjs" 2>/dev/null; then
    pass "run-advisory-cursor.mjs pins Cursor Grok 4.5 Medium and logs GITHUB_RUN_ID context"
  else
    fail "run-advisory-cursor.mjs must pin Cursor Grok 4.5 Medium and log workflow run context"
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x "$UPSERT_SCRIPT" "$RUN_SCRIPT" 2>/dev/null; then
      pass "advisory shell scripts pass shellcheck"
    else
      warn "advisory shell scripts shellcheck findings (non-fatal)"
    fi
  else
    warn "shellcheck not installed; skipped advisory script lint"
  fi

  if grep -q 'ai-review:full' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q "github.event.label.name == 'ai-review:full'" "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "advisory workflow re-runs when ai-review:full is labeled (with ai-review:live)"
  else
    fail "advisory workflow must re-run on ai-review:full label when ai-review:live is present"
  fi

  echo ""
  return 0
fi

echo "049-advisory-review-invariants.sh is sourced by test.sh only" >&2
exit 1
