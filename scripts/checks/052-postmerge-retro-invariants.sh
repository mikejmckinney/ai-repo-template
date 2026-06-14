#!/usr/bin/env bash
# scripts/checks/052-postmerge-retro-invariants.sh — post-merge retro v2 wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking post-merge retro invariants..."

  RETRO_WORKFLOW=".github/workflows/agent-postmerge-retro.yml"
  RETRO_PROMPT=".github/prompts/post-merge-retro.md"
  RETRO_FIX_PROMPT=".github/prompts/post-merge-retro-fix.md"
  RETRO_DIR="scripts/workflows/postmerge-retro"
  COLLECT_SCRIPT="${RETRO_DIR}/collect-postmerge-evidence.sh"
  RUN_SCRIPT="${RETRO_DIR}/run-postmerge-retro.sh"
  DAILY_SCRIPT="${RETRO_DIR}/run-postmerge-retro-daily.sh"
  FIX_SCRIPT="${RETRO_DIR}/run-postmerge-retro-fix.sh"
  UMBRELLA_SCRIPT="${RETRO_DIR}/create-umbrella-issue.sh"
  LIST_SCRIPT="${RETRO_DIR}/list-merges-last-24h.sh"
  SCHEMA=".github/schemas/postmerge-retro.schema.json"
  UMBRELLA_TEMPLATE=".github/templates/postmerge-retro-umbrella.md"
  FIX_PR_TEMPLATE=".github/templates/postmerge-retro-fix-pr.md"
  LABELS_SCRIPT="scripts/setup/40-ensure-labels.sh"
  ENSURE_LABELS_SCRIPT="scripts/setup/ensure-pipeline-labels.sh"
  FEEDBACK_COLLECTOR="scripts/workflows/pr-feedback/collect-pr-feedback.sh"

  for f in "$RETRO_WORKFLOW" "$RETRO_PROMPT" "$RETRO_FIX_PROMPT" "$COLLECT_SCRIPT" "$RUN_SCRIPT" \
    "$DAILY_SCRIPT" "$FIX_SCRIPT" "$UMBRELLA_SCRIPT" "$LIST_SCRIPT" "$SCHEMA" \
    "$UMBRELLA_TEMPLATE" "$FIX_PR_TEMPLATE" "$ENSURE_LABELS_SCRIPT" "$FEEDBACK_COLLECTOR"; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (post-merge retro)"
    fi
  done

  if grep -q 'schedule:' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q '0 6 \* \* \*' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow scheduled at 06:00 UTC"
  else
    fail "retro workflow missing 06:00 UTC schedule"
  fi

  if grep -q 'workflow_dispatch' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow supports manual workflow_dispatch (daily pipeline)"
  else
    fail "retro workflow must support workflow_dispatch"
  fi

  if ! grep -q 'pull_request:' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow has no pull_request close trigger (Option C)"
  else
    fail "retro workflow must not use pull_request close trigger in v2"
  fi

  if grep -q 'run-postmerge-retro-daily.sh' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'run-postmerge-retro-fix.sh' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "workflow invokes daily retro + fix scripts"
  else
    fail "workflow must invoke daily retro and fix scripts"
  fi

  if grep -q 'issues: write' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow grants issues: write"
  else
    fail "retro workflow missing issues: write"
  fi

  if grep -q 'contents: write' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'pull-requests: write' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "fix job grants contents and pull-requests write"
  else
    fail "fix job missing write permissions"
  fi

  if grep -q 'postmerge-retro-umbrella.md' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'agent-suggested' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'gh issue create' "$UMBRELLA_SCRIPT" 2>/dev/null; then
    pass "umbrella creator uses template + resilient agent-suggested label"
  else
    fail "create-umbrella-issue.sh missing template/resilient label wiring"
  fi

  if grep -q 'postmerge-retro-fix-pr.md' "$FIX_SCRIPT" 2>/dev/null; then
    pass "fix script uses postmerge-retro-fix-pr template"
  else
    fail "run-postmerge-retro-fix.sh must render postmerge-retro-fix-pr.md"
  fi

  if grep -q 'ensure-pipeline-labels.sh' "scripts/sandbox-bootstrap.sh" 2>/dev/null; then
    pass "sandbox bootstrap ensures pipeline labels"
  else
    fail "sandbox-bootstrap.sh must call ensure-pipeline-labels.sh"
  fi

  if grep -q 'collect-pr-feedback.sh' "$COLLECT_SCRIPT" 2>/dev/null; then
    pass "postmerge collector wraps collect-pr-feedback.sh"
  else
    fail "collect-postmerge-evidence.sh must wrap collect-pr-feedback.sh"
  fi

  if grep -q 'follow_up_issues' "$RETRO_PROMPT" 2>/dev/null \
    && grep -q 'dedupe_key' "$RETRO_PROMPT" 2>/dev/null; then
    pass "retro prompt defines JSON output shape"
  else
    fail "retro prompt missing required JSON contract"
  fi

  if grep -q 'merged_at' "$RUN_SCRIPT" 2>/dev/null; then
    pass "run-postmerge-retro uses merged_at gate"
  else
    fail "run-postmerge-retro.sh must gate on merged_at"
  fi

  if grep -q 'select-context' scripts/workflows/lib/prompt_helpers.py 2>/dev/null \
    && grep -qE 'prompt_helpers\.py.*select-context' "$RUN_SCRIPT" 2>/dev/null; then
    pass "post-merge retro uses catalog-driven context selection"
  else
    fail "run-postmerge-retro.sh must use prompt_helpers select-context"
  fi

  if grep -q 'POSTMERGE_RETRO_CONTEXT_PROFILE' .github/workflows/agent-postmerge-retro.yml 2>/dev/null; then
    pass "retro workflow exposes POSTMERGE_RETRO_CONTEXT_PROFILE"
  else
    fail "agent-postmerge-retro.yml missing POSTMERGE_RETRO_CONTEXT_PROFILE env"
  fi

  for label in retro-review adr:update context-pack agent-suggested; do
    if grep -q "^${label}|" "$LABELS_SCRIPT" 2>/dev/null; then
      pass "label ${label} declared in setup"
    else
      fail "label ${label} missing from $LABELS_SCRIPT"
    fi
  done

  if bash -n "$COLLECT_SCRIPT" 2>/dev/null \
    && bash -n "$RUN_SCRIPT" 2>/dev/null \
    && bash -n "$DAILY_SCRIPT" 2>/dev/null \
    && bash -n "$FIX_SCRIPT" 2>/dev/null \
    && bash -n "$UMBRELLA_SCRIPT" 2>/dev/null \
    && bash -n "$LIST_SCRIPT" 2>/dev/null; then
    pass "postmerge-retro shell scripts have valid bash syntax"
  else
    fail "postmerge-retro shell script bash -n failed"
  fi

  fixture_dir="scripts/tests/fixtures/postmerge-retro"
  llm_fixture="${fixture_dir}/sample-llm-output.txt"
  retro_fixture="${fixture_dir}/sample-retro.json"
  if [[ -f "$llm_fixture" && -f "$retro_fixture" ]]; then
    tmp="$(mktemp -d)"
    if python3 "$RETRO_DIR/extract-retro-json.py" "$llm_fixture" 382 "$tmp/retro.json" \
      && python3 "$RETRO_DIR/validate-postmerge-retro.py" "$tmp/retro.json" \
      && python3 "$RETRO_DIR/merge-daily-retro-json.py" 2026-06-11 "$tmp/retro.json" \
        >"$tmp/daily.json" \
      && python3 "$RETRO_DIR/validate-postmerge-retro-daily.py" "$tmp/daily.json"; then
      pass "extract + validate + daily merge on fixture"
    else
      fail "retro JSON fixture extraction/validation/daily merge failed"
    fi
    rm -rf "$tmp"
  else
    warn "postmerge-retro fixtures missing under $fixture_dir"
  fi

  if grep -q 'AGENTS_MD_VERSION: 26' AGENTS.md 2>/dev/null \
    && grep -q 'After context compaction' AGENTS.md 2>/dev/null \
    && grep -q 'In context' AGENTS.md 2>/dev/null \
    && grep -q 'out of compliance' AGENTS.md 2>/dev/null; then
    pass "AGENTS.md v26 includes compaction + in-context receipt rules"
  else
    fail "AGENTS.md missing v26 compaction/in-context receipt rules"
  fi

  echo ""
  return 0
fi

echo "052-postmerge-retro-invariants.sh is sourced by test.sh only" >&2
exit 1
