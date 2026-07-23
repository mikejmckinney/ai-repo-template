#!/usr/bin/env bash
# Shared fix PR body, outcome evidence, and conditional sandbox finalization.

finalize_append_verify_sections() {
  local body_file="$1"
  local verify_json="$2"
  local lib_dir="$3"

  if [[ ! -f "$verify_json" ]]; then
    {
      echo ""
      echo "## Fix verification"
      echo ""
      echo "_fix-verify.json missing — fix agent must record per-finding verify outcomes._"
      echo ""
      echo "## User outcome evidence"
      echo ""
      echo "_fix-verify.json missing - no material-claim evidence is available._"
      echo ""
    } >>"$body_file"
    echo "::warning::Missing fix-verify.json at ${verify_json}" >&2
    return 0
  fi

  python3 "$lib_dir/render-fix-pr-sections.py" "$verify_json" all >>"$body_file"
}

maybe_sandbox_sync() {
  local repo_root="$1"
  local sandbox_branch="$2"
  local title="$3"
  local verify_json="$4"
  local lib_dir="$5"

  if [[ "${FIX_JOB_SANDBOX_VERIFY:-false}" != "true" ]]; then
    return 0
  fi

  local needs_sync="false"
  if [[ -f "$verify_json" ]]; then
    needs_sync="$(jq -r '.sandbox.needs_sync // false' "$verify_json" 2>/dev/null || echo false)"
    local pr_url
    pr_url="$(jq -r '.sandbox.pr_url // ""' "$verify_json" 2>/dev/null || true)"
    if [[ -n "$pr_url" && "$pr_url" != "n/a" && "$pr_url" != "null" ]]; then
      echo "::notice::sandbox-sync skipped (fix-verify already has sandbox PR URL)"
      return 0
    fi
  fi

  if [[ "$needs_sync" != "true" ]]; then
    echo "::notice::sandbox-sync skipped (fix-verify sandbox.needs_sync is not true)"
    return 0
  fi

  local body_file
  body_file="$(mktemp)"
  {
    echo "Automated sandbox sync from upstream fix job."
    echo ""
    echo "Upstream verification: see fix-verify.json on the fix branch."
  } >"$body_file"

  # shellcheck source=sandbox-sync-fix-branch.sh
  source "$lib_dir/sandbox-sync-fix-branch.sh"
  local sandbox_pr_url
  sandbox_pr_url="$(sandbox_sync_fix_branch "$repo_root" "$sandbox_branch" "$title" "$body_file")"
  rm -f "$body_file"

  if [[ -n "$sandbox_pr_url" && -f "$verify_json" ]]; then
    local tmp
    tmp="$(mktemp)"
    jq --arg url "$sandbox_pr_url" '
      .sandbox.pr_url = $url |
      .sandbox.issue_url = (.sandbox.issue_url // "n/a") |
      .outcome_evidence.claims += [{
        material_claim: "Candidate fix behavior is available in the sibling repository for default-branch verification.",
        environment: "sibling GitHub repository",
        why_representative: "The affected GitHub behavior requires candidate code on a repository ref.",
        implementation_sha: "controller:current-head",
        action_performed: "Published the candidate fix branch to the sibling repository.",
        expected_result: "A sandbox PR exposes the candidate code for the required trigger walkthrough.",
        observed_result: "The sandbox PR was created; workflow run evidence is recorded separately when required.",
        artifact: $url,
        artifact_type: "sandbox-pr",
        redaction: "No credential values are included.",
        retention: "PR-lifetime GitHub record.",
        evidence_reuse: "none",
        result: "pass"
      }]' \
      "$verify_json" >"$tmp"
    mv "$tmp" "$verify_json"
  fi
}
