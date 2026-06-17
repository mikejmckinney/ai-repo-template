#!/usr/bin/env bash
# scripts/workflows/lib/finalize-fix-pr.sh — shared fix PR body + sandbox finalization.

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
      echo "## Sandbox dogfood evidence"
      echo ""
      echo "Sandbox issue: n/a"
      echo "Sandbox PR: n/a"
      echo ""
    } >>"$body_file"
    echo "::warning::Missing fix-verify.json at ${verify_json}" >&2
    return 0
  fi

  if ! python3 "$lib_dir/render-fix-pr-sections.py" "$verify_json" all >>"$body_file" 2>/dev/null; then
    {
      echo ""
      echo "## Fix verification"
      echo ""
      echo "_fix-verify.json present but could not be rendered — see branch artifact._"
      echo ""
      echo "## Sandbox dogfood evidence"
      echo ""
      echo "Sandbox issue: n/a"
      echo "Sandbox PR: n/a"
      echo ""
    } >>"$body_file"
    echo "::warning::render-fix-pr-sections.py failed for ${verify_json}" >&2
  fi
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
  local sandbox_pr_url=""
  sandbox_pr_url="$(sandbox_sync_fix_branch "$repo_root" "$sandbox_branch" "$title" "$body_file" || true)"
  rm -f "$body_file"

  if [[ -z "$sandbox_pr_url" ]]; then
    echo "::warning::sandbox-sync failed or returned no PR URL; continuing upstream PR finalization" >&2
    return 0
  fi

  if [[ -f "$verify_json" ]]; then
    local tmp
    tmp="$(mktemp)"
    jq --arg url "$sandbox_pr_url" '.sandbox.pr_url = $url | .sandbox.issue_url = (.sandbox.issue_url // "n/a")' \
      "$verify_json" >"$tmp"
    mv "$tmp" "$verify_json"
  fi
}
