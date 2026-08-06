#!/usr/bin/env bash
# scripts/checks/053-weekly-review-invariants.sh — weekly repo review wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking weekly review invariants..."

  WEEKLY_WORKFLOW=".github/workflows/agent-weekly-review.yml"
  WEEKLY_PROMPT=".github/prompts/weekly-repo-review.md"
  WEEKLY_FIX_PROMPT=".github/prompts/weekly-repo-review-fix.md"
  WEEKLY_DIR="scripts/workflows/weekly-review"
  SCAN_SCRIPT="${WEEKLY_DIR}/run-weekly-review-scan.sh"
  FIX_SCRIPT="${WEEKLY_DIR}/run-weekly-review-fix.sh"
  UMBRELLA_SCRIPT="${WEEKLY_DIR}/create-umbrella-issue.sh"
  WRITE_UMBRELLA_REF_SCRIPT="${WEEKLY_DIR}/write-umbrella-issue-ref.sh"
  UMBRELLA_TEMPLATE=".github/templates/weekly-review-umbrella.md"
  FIX_PR_TEMPLATE=".github/templates/weekly-review-fix-pr.md"
  LIB_DIR="scripts/workflows/lib"
  FIX_PROVIDER_CASCADE="$LIB_DIR/run-fix-provider-cascade.sh"
  # shellcheck source=scripts/lib/search.sh
  source "scripts/lib/search.sh"

  if grep -q 'OPENCODE_OUTPUT_SCHEMA' "$SCAN_SCRIPT" 2>/dev/null \
    && grep -q 'run_fix_provider_cascade' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'OPENCODE_FIX_MODE=true' "$FIX_PROVIDER_CASCADE" 2>/dev/null \
    && grep -q 'OPENCODE_GITHUB_TOKEN' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'npm ci --prefix .github/agent-runtime' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && ! grep -q 'AGENT_RUNTIME_IMAGE' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly scan/fix uses locked OpenCode runtime and isolated fix attempts"
  else
    fail "weekly review missing OpenCode install, schema validation, or isolation wiring"
  fi

  if search_fixed 'schedule:' "$WEEKLY_WORKFLOW" >/dev/null 2>&1 \
    && search_regex '0 7 \* \* 0' "$WEEKLY_WORKFLOW" >/dev/null 2>&1; then
    pass "weekly workflow scheduled Sunday 07:00 UTC"
  else
    fail "weekly workflow missing Sunday 07:00 UTC schedule"
  fi

  if search_fixed 'workflow_dispatch' "$WEEKLY_WORKFLOW" >/dev/null 2>&1; then
    pass "weekly workflow supports manual workflow_dispatch"
  else
    fail "weekly workflow must support workflow_dispatch"
  fi

  if python3 - "$WEEKLY_WORKFLOW" <<'PY'; then
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
fix = text.split("  weekly-fix:", 1)[1]
permissions = fix.split("    env:", 1)[0]
actual = dict(re.findall(r"^      ([a-z-]+): (read|write|none)$", permissions, re.MULTILINE))
expected = {
    "actions": "read",
    "contents": "write",
    "pull-requests": "write",
    "issues": "write",
}
raise SystemExit(0 if actual == expected else 1)
PY
    pass "weekly fix job grants exact least-privilege recovery permissions"
  else
    fail "weekly fix job permissions must exactly include read-only artifact recovery"
  fi

  if ! search_fixed 'pull_request:' "$WEEKLY_WORKFLOW" >/dev/null 2>&1; then
    pass "weekly workflow has no pull_request trigger"
  else
    fail "weekly workflow must not use pull_request trigger"
  fi

  if grep -q 'run-weekly-review-weekly.sh' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'run-weekly-review-fix.sh' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "workflow invokes weekly scan + fix scripts"
  else
    fail "workflow must invoke weekly scan and fix scripts"
  fi

  if search_fixed 'group: weekly-review' "$WEEKLY_WORKFLOW" >/dev/null 2>&1; then
    pass "weekly workflow uses dedicated concurrency group"
  else
    fail "weekly workflow missing weekly-review concurrency group"
  fi

  if grep -q 'WEEKLY_REVIEW_CONTEXT_PROFILE' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly workflow exposes WEEKLY_REVIEW_CONTEXT_PROFILE (default full)"
  else
    fail "agent-weekly-review.yml missing WEEKLY_REVIEW_CONTEXT_PROFILE env"
  fi

  if grep -q 'ADVISORY_ANTIGRAVITY_ENABLED' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'antigravity' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly workflow documents antigravity provider routing"
  else
    fail "agent-weekly-review.yml missing antigravity provider wiring"
  fi

  if grep -q 'select-context' "$LIB_DIR/prompt_helpers.py" 2>/dev/null \
    && grep -qE 'prompt_helpers\.py.*select-context' "$SCAN_SCRIPT" 2>/dev/null \
    && grep -q 'changed-files.txt' "$SCAN_SCRIPT" 2>/dev/null \
    && grep -q 'list_advisory_providers weekly-scan' "$SCAN_SCRIPT" 2>/dev/null \
    && grep -q 'invoke_advisory_llm' "$SCAN_SCRIPT" 2>/dev/null \
    && grep -q 'run-weekly-antigravity.py' "$SCAN_SCRIPT" 2>/dev/null; then
    pass "weekly scan uses context pack + shared provider routing"
  else
    fail "run-weekly-review-scan.sh must use select-context + shared providers + antigravity path"
  fi

  if grep -qE 'read the repository working tree\b|Inspect the repository\b' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'context pack' "$WEEKLY_PROMPT" 2>/dev/null; then
    pass "weekly prompt instructs repo inspection (not supplied-artifacts-only)"
  else
    fail "weekly-repo-review.md must instruct agent to inspect repo working tree"
  fi

  if grep -q 'weekly-review-fix-pr.md' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'checkout-fix-branch.sh' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'link-fix-pr-to-issue.sh' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'batch_fix_publish' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'leaving draft PR' "$LIB_DIR/run-batch-fix.sh" 2>/dev/null \
    && grep -q 'Fixes #' "$FIX_PR_TEMPLATE" 2>/dev/null \
    && grep -q 'WEEKLY_REVIEW_FIX_REEXEC' "$FIX_SCRIPT" 2>/dev/null; then
    pass "weekly fix uses template + native issue link + re-exec guard"
  else
    fail "run-weekly-review-fix.sh must render fix PR, link issue, and re-exec from temp copy"
  fi

  if grep -q 'validate-fix-verification.py' "$FIX_PROVIDER_CASCADE" 2>/dev/null \
    && ! grep -q 'batch_fix_write_verify_stub\|creating minimal stub' "$FIX_SCRIPT" 2>/dev/null; then
    pass "weekly fixes require valid verification before promotion"
  else
    fail "weekly fixes must fail closed without valid per-finding verification"
  fi

  if grep -q 'render-umbrella-findings.py' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q '{{FINDING_BLOCKS}}' "$UMBRELLA_TEMPLATE" 2>/dev/null \
    && grep -q '{{TRIAGE_ROWS}}' "$UMBRELLA_TEMPLATE" 2>/dev/null \
    && grep -q 'merge-umbrella-content.py' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'repo-' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'weekly-review:finding:' "${WEEKLY_DIR}/render-umbrella-findings.py" 2>/dev/null; then
    pass "umbrella issue renders hybrid triage summary and detailed findings"
  else
    fail "weekly umbrella must render TRIAGE_ROWS and detailed FINDING_BLOCKS"
  fi

  if grep -q 'write-umbrella-issue-ref.sh' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'umbrella_issue' "$WRITE_UMBRELLA_REF_SCRIPT" 2>/dev/null \
    && grep -q 'post-weekly-review-json-comment.sh' "$UMBRELLA_SCRIPT" 2>/dev/null; then
    pass "weekly umbrella records umbrella_issue ref + JSON snapshot comment"
  else
    fail "weekly review missing umbrella_issue ref / JSON snapshot wiring"
  fi

  if grep -q 'follow_up_issues' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'dedupe_key' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'repro_steps' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'triage_version' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'impact_magnitude' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'trigger_likelihood' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'affected_scope' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'reversibility' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'confidence' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'uncertainty' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'priority_band.*derived' "$WEEKLY_PROMPT" 2>/dev/null; then
    pass "weekly prompt defines classifier JSON shape with repro_steps"
  else
    fail "weekly prompt missing required JSON contract (repro_steps)"
  fi

  if grep -q 'fix-verify' "$WEEKLY_FIX_PROMPT" 2>/dev/null; then
    pass "weekly fix prompt references fix-verify.json"
  else
    fail "weekly-repo-review-fix prompt missing fix-verify rules"
  fi

  if grep -q 'FIX_JOB_SANDBOX_VERIFY' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'SANDBOX_BOOTSTRAP_TOKEN' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly fix job wires sandbox verify env + token"
  else
    fail "agent-weekly-review.yml fix job missing FIX_JOB_SANDBOX_VERIFY / SANDBOX_BOOTSTRAP_TOKEN"
  fi

  if python3 -m py_compile "${WEEKLY_DIR}/run-weekly-antigravity.py" 2>/dev/null \
    && python3 -m py_compile "${WEEKLY_DIR}/render-umbrella-findings.py" 2>/dev/null \
    && python3 -m py_compile "${WEEKLY_DIR}/merge-umbrella-content.py" 2>/dev/null \
    && python3 -m py_compile "$LIB_DIR/finding_priority.py" 2>/dev/null \
    && python3 -m py_compile "$LIB_DIR/superseded_findings.py" 2>/dev/null; then
    pass "weekly-review Python helpers compile"
  else
    fail "weekly-review Python helper compilation failed"
  fi

  fixture_dir="scripts/tests/fixtures/weekly-review"
  review_fixture="${fixture_dir}/sample-review.json"
  if [[ -f "$review_fixture" ]]; then
    tmp="$(mktemp -d)"
    if python3 "${WEEKLY_DIR}/validate-weekly-review.py" "$review_fixture" \
      && python3 "${WEEKLY_DIR}/build-weekly-review-batch.py" 2026-W24 2026-06-14 "$review_fixture" \
        >"$tmp/weekly.json" \
      && python3 "${WEEKLY_DIR}/validate-weekly-review-batch.py" "$tmp/weekly.json"; then
      pass "weekly JSON fixture validation + batch build"
    else
      fail "weekly JSON fixture validation/batch build failed"
    fi
    rm -rf "$tmp"
  else
    warn "weekly-review fixtures missing under $fixture_dir"
  fi

  echo ""
  return 0
fi

echo "053-weekly-review-invariants.sh is sourced by test.sh only" >&2
exit 1
