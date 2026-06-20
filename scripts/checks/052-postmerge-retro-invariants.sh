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
  DAILY_DISPATCH_SCRIPT="${RETRO_DIR}/run-postmerge-retro-daily-dispatch.sh"
  DAILY_SELECT_SCRIPT="${RETRO_DIR}/daily-retro-select-prs.sh"
  FIX_SCRIPT="${RETRO_DIR}/run-postmerge-retro-fix.sh"
  CLASSIFIER_SCRIPT="${RETRO_DIR}/classify-finding-priority.py"
  COVERAGE_SCRIPT="${RETRO_DIR}/compute-evidence-coverage.py"
  COVERAGE_META_SCRIPT="${RETRO_DIR}/render-evidence-coverage-meta.py"
  DAILY_SCHEMA=".github/schemas/postmerge-retro-daily.schema.json"
  PARALLEL_SCRIPT="${RETRO_DIR}/run-postmerge-retro-parallel.sh"
  UMBRELLA_LINK_SCRIPT="${RETRO_DIR}/update-umbrella-fix-link.sh"
  RESOLVE_UMBRELLA_SCRIPT="${RETRO_DIR}/resolve-umbrella-issue.sh"
  WRITE_UMBRELLA_REF_SCRIPT="${RETRO_DIR}/write-umbrella-issue-ref.sh"
  UMBRELLA_SCRIPT="${RETRO_DIR}/create-umbrella-issue.sh"
  UMBRELLA_TABLE_SCRIPT="${RETRO_DIR}/umbrella-findings-table.py"
  LIST_SCRIPT="${RETRO_DIR}/list-merges-last-24h.sh"
  SCHEMA=".github/schemas/postmerge-retro.schema.json"
  LINK_SCRIPT="scripts/workflows/lib/link-fix-pr-to-issue.sh"
  CHECKOUT_FIX_BRANCH_SCRIPT="scripts/workflows/lib/checkout-fix-branch.sh"
  UMBRELLA_TEMPLATE=".github/templates/postmerge-retro-umbrella.md"
  FIX_PR_TEMPLATE=".github/templates/postmerge-retro-fix-pr.md"
  LABELS_SCRIPT="scripts/setup/40-ensure-labels.sh"
  ENSURE_LABELS_SCRIPT="scripts/setup/ensure-pipeline-labels.sh"
  FEEDBACK_COLLECTOR="scripts/workflows/pr-feedback/collect-pr-feedback.sh"

  for f in "$RETRO_WORKFLOW" "$RETRO_PROMPT" "$RETRO_FIX_PROMPT" "$COLLECT_SCRIPT" "$RUN_SCRIPT" \
    "$DAILY_SCRIPT" "$DAILY_DISPATCH_SCRIPT" "$DAILY_SELECT_SCRIPT" "$FIX_SCRIPT" "$UMBRELLA_SCRIPT" "$UMBRELLA_LINK_SCRIPT" \
    "$RESOLVE_UMBRELLA_SCRIPT" "$WRITE_UMBRELLA_REF_SCRIPT" "$LIST_SCRIPT" "$SCHEMA" \
    "$UMBRELLA_TEMPLATE" "$FIX_PR_TEMPLATE" "$LINK_SCRIPT" "$CHECKOUT_FIX_BRANCH_SCRIPT" \
    "$ENSURE_LABELS_SCRIPT" "$FEEDBACK_COLLECTOR" "$CLASSIFIER_SCRIPT" "$PARALLEL_SCRIPT" \
    "$UMBRELLA_TABLE_SCRIPT" "$COVERAGE_SCRIPT" "$COVERAGE_META_SCRIPT" "$DAILY_SCHEMA"; do
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

  if grep -q 'daily-pipeline:' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'run-postmerge-retro-daily-dispatch.sh' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'run-postmerge-retro-fix.sh' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "workflow uses single daily-pipeline job with retro + fix scripts"
  else
    fail "workflow must use daily-pipeline job invoking retro and fix scripts"
  fi

  if ! grep -q 'daily-retro:' "$RETRO_WORKFLOW" 2>/dev/null \
    && ! grep -q 'daily-fix:' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "workflow consolidated to single job (no daily-retro/daily-fix split)"
  else
    fail "workflow must not define separate daily-retro and daily-fix jobs (#446)"
  fi

  if grep -q 'force_re_retro_prs' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'POSTMERGE_RETRO_IGNORE_RETRO_DEDUPE' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'list-indexed-merge-shas.sh' "$DAILY_SELECT_SCRIPT" 2>/dev/null \
    && grep -q 'merge_commit_sha' "$RUN_SCRIPT" 2>/dev/null; then
    pass "merge_commit_sha dedupe + operator overrides wired"
  else
    fail "postmerge retro missing merge_commit_sha dedupe wiring"
  fi

  if grep -q 'Suggested fix' "$UMBRELLA_TEMPLATE" 2>/dev/null \
    && grep -q 'trigger_likelihood' "$UMBRELLA_TEMPLATE" 2>/dev/null \
    && grep -q 'fix_cost' "$UMBRELLA_TEMPLATE" 2>/dev/null \
    && grep -q 'regression_guard' "$UMBRELLA_TEMPLATE" 2>/dev/null \
    && grep -q 'umbrella-findings-table.py' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'extract-suggested-fix.py' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'migrate_findings_table' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'trigger_likelihood' "$UMBRELLA_TABLE_SCRIPT" 2>/dev/null \
    && grep -q 'Current main (HEAD)' "$RUN_SCRIPT" 2>/dev/null \
    && grep -q 'mark-superseded-findings.py' "$FIX_SCRIPT" 2>/dev/null; then
    pass "layers B–D: HEAD lens, superseded helper, triage umbrella columns + Suggested fix"
  else
    fail "postmerge retro missing layers B–D wiring"
  fi

  if grep -q 'impact' "$RETRO_PROMPT" 2>/dev/null \
    && grep -q 'trigger_likelihood' "$RETRO_PROMPT" 2>/dev/null \
    && grep -q 'fix_cost' "$RETRO_PROMPT" 2>/dev/null \
    && ! grep -q '"severity"' "$RETRO_PROMPT" 2>/dev/null \
    && grep -q 'impact' "$SCHEMA" 2>/dev/null \
    && grep -q 'classify-finding-priority.py' "$RETRO_DIR/validate-postmerge-retro.py" 2>/dev/null \
    && grep -q 'derive_priority_band' "$CLASSIFIER_SCRIPT" 2>/dev/null; then
    pass "finding classifier schema + prompt + validator wired (#456)"
  else
    fail "postmerge retro missing finding classifier contract (#456)"
  fi

  if grep -q 'compute-evidence-coverage.py' "$RUN_SCRIPT" 2>/dev/null \
    && grep -q 'pr_evidence_coverage' "$RETRO_DIR/merge-daily-retro-json.py" 2>/dev/null \
    && grep -q 'pr_evidence_coverage' "$RETRO_DIR/validate-postmerge-retro-daily.py" 2>/dev/null \
    && grep -q 'render-evidence-coverage-meta.py' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'EVIDENCE_COVERAGE' "$UMBRELLA_TEMPLATE" 2>/dev/null \
    && grep -q 'compute-evidence-coverage.py' "$RETRO_DIR/run-postmerge-retro-monolithic.sh" 2>/dev/null; then
    pass "evidence coverage pre-check + Meta render wired (#460)"
  else
    fail "postmerge retro missing evidence coverage truncation visibility (#460)"
  fi

  if grep -q 'POSTMERGE_RETRO_PARALLEL_MAX:-6' "$PARALLEL_SCRIPT" 2>/dev/null \
    && grep -q 'parallel_max' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'POSTMERGE_RETRO_PARALLEL_MAX' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "parallel retro defaults POSTMERGE_RETRO_PARALLEL_MAX to 6 + workflow dispatch input"
  else
    fail "run-postmerge-retro-parallel.sh must default POSTMERGE_RETRO_PARALLEL_MAX to 6 and workflow must expose parallel_max"
  fi

  if grep -q 'issues: write' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow grants issues: write"
  else
    fail "retro workflow missing issues: write"
  fi

  if grep -q 'contents: write' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'pull-requests: write' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "daily-pipeline job grants contents and pull-requests write"
  else
    fail "daily-pipeline job missing write permissions"
  fi

  if grep -q 'postmerge-retro-umbrella.md' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'agent-suggested' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'gh issue create' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'existing-body.md' "$UMBRELLA_SCRIPT" 2>/dev/null; then
    pass "umbrella creator uses template + resilient agent-suggested label + body file append"
  else
    fail "create-umbrella-issue.sh missing template/resilient label/body-file append wiring"
  fi

  if grep -q 'write-umbrella-issue-ref.sh' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'umbrella_issue' "$WRITE_UMBRELLA_REF_SCRIPT" 2>/dev/null \
    && grep -q 'Created umbrella issue #' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q '>&2' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'normalize_issue_num' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && [[ -f "${RETRO_DIR}/post-daily-retro-json-comment.sh" ]] \
    && [[ -f "${RETRO_DIR}/fetch-daily-retro-json-from-issue.sh" ]]; then
    pass "umbrella step records umbrella_issue ref + JSON snapshot comment + fix-only restore"
  else
    fail "postmerge retro missing umbrella_issue ref / daily JSON snapshot wiring"
  fi

  if grep -q 'resolve-umbrella-issue.sh' "$UMBRELLA_LINK_SCRIPT" 2>/dev/null \
    && grep -q 'resolve-umbrella-issue.sh' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'umbrella_issue_num' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'UMBRELLA_ISSUE_NUM' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "fix step resolves umbrella issue from JSON/env (search fallback only)"
  else
    fail "postmerge retro missing resolve-umbrella-issue wiring in fix path"
  fi

  if grep -q 'attempt-\${GITHUB_RUN_ATTEMPT}' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q "has_daily_json == 'true'" "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'fix_only' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro workflow uses attempt-scoped artifacts + fix-only dispatch"
  else
    fail "agent-postmerge-retro.yml missing attempt artifact / fix-only wiring"
  fi

  if grep -q 'Pin RUN_DATE' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'GITHUB_ENV' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'RUN_DATE=\${RUN_DATE' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "RUN_DATE pinned to GITHUB_ENV before pipeline steps"
  else
    fail "agent-postmerge-retro.yml must pin RUN_DATE to GITHUB_ENV"
  fi

  if grep -q 'artifact_run_id' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'gh run download' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'fetch-daily-retro-json-from-issue.sh' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "fix_only downloads artifact_run_id before issue snapshot restore"
  else
    fail "fix_only must prefer artifact_run_id over issue snapshot restore"
  fi

  if [[ -f "${RETRO_DIR}/parse-daily-json-snapshot.py" ]] \
    && grep -q 'parse-daily-json-snapshot.py' "${RETRO_DIR}/fetch-daily-retro-json-from-issue.sh" 2>/dev/null; then
    pass "issue snapshot restore validates JSON via parse-daily-json-snapshot.py"
  else
    fail "fetch-daily-retro-json-from-issue.sh must validate snapshots with parse-daily-json-snapshot.py"
  fi

  if grep -q 'FIX_REEXEC_DIR' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'has_diff' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'leaving draft PR' "$FIX_SCRIPT" 2>/dev/null; then
    pass "fix script uses artifact re-exec dir + skips PR edit on no-op rerun"
  else
    fail "run-postmerge-retro-fix.sh missing re-exec workdir / no-op PR edit guard"
  fi

  if grep -q 'postmerge-retro-fix-pr.md' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'checkout-fix-branch.sh' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'update-umbrella-fix-link.sh' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'link-fix-pr-to-issue.sh' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'Fixes #' ".github/templates/postmerge-retro-fix-pr.md" 2>/dev/null \
    && grep -q 'POSTMERGE_RETRO_FIX_REEXEC' "$FIX_SCRIPT" 2>/dev/null; then
    pass "fix script uses postmerge-retro-fix-pr template + umbrella link update + native issue link + re-exec guard"
  else
    fail "run-postmerge-retro-fix.sh must render fix PR, update umbrella link, link issue, and re-exec from temp copy"
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
    && grep -q 'dedupe_key' "$RETRO_PROMPT" 2>/dev/null \
    && grep -q 'repro_steps' "$RETRO_PROMPT" 2>/dev/null; then
    pass "retro prompt defines JSON output shape with repro_steps"
  else
    fail "retro prompt missing required JSON contract (repro_steps)"
  fi

  if grep -q 'fix-verify' "$RETRO_FIX_PROMPT" 2>/dev/null \
    && grep -q 'cant_reproduce' "$RETRO_FIX_PROMPT" 2>/dev/null; then
    pass "retro fix prompt defines per-finding verification (ADR-029 §1.1)"
  else
    fail "post-merge-retro-fix prompt missing fix-verify / cant_reproduce rules"
  fi

  if grep -q 'FIX_JOB_SANDBOX_VERIFY' "$RETRO_WORKFLOW" 2>/dev/null \
    && grep -q 'SANDBOX_BOOTSTRAP_TOKEN' "$RETRO_WORKFLOW" 2>/dev/null; then
    pass "retro fix job wires sandbox verify env + token"
  else
    fail "agent-postmerge-retro.yml fix job missing FIX_JOB_SANDBOX_VERIFY / SANDBOX_BOOTSTRAP_TOKEN"
  fi

  for lib in pick-advisory-provider.sh invoke-advisory-llm.sh fix-phase-log.sh \
    sandbox-sync-fix-branch.sh finalize-fix-pr.sh render-fix-pr-sections.py; do
    if [[ -f "scripts/workflows/lib/$lib" ]]; then
      pass "workflow lib $lib exists"
    else
      fail "missing scripts/workflows/lib/$lib"
    fi
  done

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
    && bash -n "$DAILY_DISPATCH_SCRIPT" 2>/dev/null \
    && bash -n "$DAILY_SELECT_SCRIPT" 2>/dev/null \
    && bash -n "${RETRO_DIR}/run-postmerge-retro-monolithic.sh" 2>/dev/null \
    && bash -n "${RETRO_DIR}/run-postmerge-retro-parallel.sh" 2>/dev/null \
    && bash -n "$FIX_SCRIPT" 2>/dev/null \
    && bash -n "$UMBRELLA_SCRIPT" 2>/dev/null \
    && bash -n "$RESOLVE_UMBRELLA_SCRIPT" 2>/dev/null \
    && bash -n "$WRITE_UMBRELLA_REF_SCRIPT" 2>/dev/null \
    && bash -n "$UMBRELLA_LINK_SCRIPT" 2>/dev/null \
    && bash -n "$LINK_SCRIPT" 2>/dev/null \
    && bash -n "${RETRO_DIR}/post-daily-retro-json-comment.sh" 2>/dev/null \
    && bash -n "${RETRO_DIR}/fetch-daily-retro-json-from-issue.sh" 2>/dev/null \
    && bash -n "scripts/workflows/lib/pick-advisory-provider.sh" 2>/dev/null \
    && bash -n "scripts/workflows/lib/invoke-advisory-llm.sh" 2>/dev/null \
    && bash -n "scripts/workflows/lib/fix-phase-log.sh" 2>/dev/null \
    && bash -n "scripts/workflows/lib/sandbox-sync-fix-branch.sh" 2>/dev/null \
    && bash -n "scripts/workflows/lib/finalize-fix-pr.sh" 2>/dev/null \
    && bash -n "${RETRO_DIR}/list-indexed-merge-shas.sh" 2>/dev/null \
    && bash -n "${RETRO_DIR}/append-merge-index-markers.sh" 2>/dev/null \
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

  run_bats_check scripts/tests/postmerge-retro-batch.bats "postmerge-retro-batch.bats"

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
