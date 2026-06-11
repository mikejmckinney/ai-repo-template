#!/usr/bin/env bash
# scripts/checks/052-postmerge-retro-invariants.sh — PR 4 post-merge retro wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking post-merge retro invariants..."

  RETRO_WORKFLOW=".github/workflows/agent-postmerge-retro.yml"
  RETRO_PROMPT=".github/prompts/post-merge-retro.md"
  RETRO_DIR="scripts/workflows/postmerge-retro"
  COLLECT_SCRIPT="${RETRO_DIR}/collect-postmerge-evidence.sh"
  RUN_SCRIPT="${RETRO_DIR}/run-postmerge-retro.sh"
  CREATE_SCRIPT="${RETRO_DIR}/postmerge-retro-create-issues.sh"
  SCHEMA=".github/schemas/postmerge-retro.schema.json"
  LABELS_SCRIPT="scripts/setup/40-ensure-labels.sh"
  FEEDBACK_COLLECTOR="scripts/workflows/pr-feedback/collect-pr-feedback.sh"

  for f in "$RETRO_WORKFLOW" "$RETRO_PROMPT" "$COLLECT_SCRIPT" "$RUN_SCRIPT" "$CREATE_SCRIPT" "$SCHEMA" "$FEEDBACK_COLLECTOR"; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (post-merge retro)"
    fi
  done

  if grep -q 'retro-review' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'pull_request' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'closed' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow is label-gated on merged PR closed events"
  else
    fail "retro workflow missing merged+label gate"
  fi

  if grep -q 'workflow_dispatch' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'create_issues' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow supports manual workflow_dispatch"
  else
    fail "retro workflow must support workflow_dispatch with create_issues input"
  fi

  if grep -q 'issues: write' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow grants issues: write for follow-up issue creation"
  else
    fail "retro workflow missing issues: write"
  fi

  if grep -q 'scripts/workflows/postmerge-retro/run-postmerge-retro.sh' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "workflow invokes scripts/workflows/postmerge-retro (AP8)"
  else
    fail "workflow must invoke run-postmerge-retro.sh"
  fi

  if grep -q 'collect-pr-feedback.sh' "$COLLECT_SCRIPT" 2>/dev/null; then
    pass "postmerge collector wraps collect-pr-feedback.sh"
  else
    fail "collect-postmerge-evidence.sh must wrap collect-pr-feedback.sh"
  fi

  if grep -q 'follow_up_issues' "$RETRO_PROMPT" 2>/dev/null \
    && grep -q 'dedupe_key' "$RETRO_PROMPT" 2>/dev/null \
    && grep -q 'JSON only' "$RETRO_PROMPT" 2>/dev/null; then
    pass "retro prompt defines JSON output shape"
  else
    fail "retro prompt missing required JSON contract"
  fi

  if grep -q 'postmerge-retro:pr=' "$CREATE_SCRIPT" 2>/dev/null \
    && grep -q 'agent-suggested' "$CREATE_SCRIPT" 2>/dev/null; then
    pass "issue creator uses dedupe markers and agent-suggested label"
  else
    fail "postmerge-retro-create-issues.sh missing dedupe marker logic"
  fi

  for label in retro-review retro:adr retro:context-pack adr:update context-pack; do
    if grep -q "^${label}|" "$LABELS_SCRIPT" 2>/dev/null; then
      pass "label ${label} declared in setup"
    else
      fail "label ${label} missing from $LABELS_SCRIPT"
    fi
  done

  if bash -n "$COLLECT_SCRIPT" 2>/dev/null \
    && bash -n "$RUN_SCRIPT" 2>/dev/null \
    && bash -n "$CREATE_SCRIPT" 2>/dev/null; then
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
      && python3 "$RETRO_DIR/validate-postmerge-retro.py" "$tmp/retro.json"; then
      pass "extract-retro-json + validate-postmerge-retro on fixture"
    else
      fail "retro JSON fixture extraction/validation failed"
    fi
    rm -rf "$tmp"
  else
    warn "postmerge-retro fixtures missing under $fixture_dir"
  fi

  echo ""
  return 0
fi

echo "052-postmerge-retro-invariants.sh is sourced by test.sh only" >&2
exit 1
