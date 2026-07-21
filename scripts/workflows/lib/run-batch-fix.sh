#!/usr/bin/env bash
# Shared commit and publication lifecycle for daily and weekly batch-fix jobs.

batch_fix_strip_workflow_changes() {
  local paths=()
  local path
  while IFS= read -r -d '' path; do
    paths+=("$path")
  done < <(git status --porcelain .github/workflows/ 2>/dev/null | awk '{print $2}' | tr '\n' '\0')
  if ((${#paths[@]} == 0)); then
    return 0
  fi
  echo "::notice::Stripping ${#paths[@]} .github/workflows/ change(s) from fix commit" >&2
  for path in "${paths[@]}"; do
    if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
      git checkout HEAD -- "$path"
    else
      rm -f "$path"
    fi
  done
}

batch_fix_write_verify_stub() {
  local output="$1" run_kind="$2" key_name="$3" key_value="$4" input_json="$5"
  python3 - "$output" "$run_kind" "$key_name" "$key_value" "$input_json" <<'PY'
import json
import sys
from pathlib import Path

output, run_kind, key_name, key_value, input_path = sys.argv[1:]
batch = json.loads(Path(input_path).read_text(encoding="utf-8"))
rows = []
for item in batch.get("findings") or []:
    if item.get("category") != "follow_up_issues":
        continue
    rows.append(
        {
            "dedupe_key": item.get("dedupe_key", ""),
            "repro_steps": item.get("repro_steps") or [],
            "verify": {
                "pre": "pending",
                "post": "pending",
                "sandbox": "n/a",
                "notes": "stub — fix agent did not write fix-verify.json",
            },
        }
    )
payload = {
    key_name: key_value,
    "run_kind": run_kind,
    "findings": rows,
    "sandbox": {
        "needs_sync": False,
        "issue_url": "n/a",
        "pr_url": "n/a",
        "skip_reason": "fix-verify stub",
        "workflow_runs": [],
    },
    "test_sh": "unknown",
}
output_path = Path(output)
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
}

batch_fix_commit_changes() {
  local commit_message="$1" override_file="${2:-}"
  # shellcheck disable=SC2034 # consumed by the sourcing cadence adapter
  BATCH_FIX_HAS_DIFF=0
  if [[ -z "$(git status --porcelain)" ]]; then
    echo "::warning::Fix pass produced no git diff"
    return 0
  fi
  if [[ -n "$override_file" && -f "$override_file" ]]; then
    commit_message="$(head -1 "$override_file")"
  fi
  git add -A
  git reset HEAD -- .github/workflows/ 2>/dev/null || true
  git checkout HEAD -- .github/workflows/ 2>/dev/null || true
  git commit -m "$commit_message"
  # shellcheck disable=SC2034 # consumed by the sourcing cadence adapter
  BATCH_FIX_HAS_DIFF=1
}

batch_fix_link_pr_to_umbrella() {
  local repo="$1" pr_ref="$2" run_key="$3" input_json="$4"
  local resolve_script="$5" link_script="$6"
  local pr_num umbrella_num
  pr_num="${pr_ref##*/}"
  [[ "$pr_num" =~ ^[0-9]+$ ]] || return 0
  umbrella_num="$(bash "$resolve_script" "$run_key" "$input_json" 2>/dev/null || true)"
  [[ "$umbrella_num" =~ ^[1-9][0-9]*$ ]] || return 0
  bash "$link_script" "$repo" "$pr_num" "$umbrella_num"
}

batch_fix_publish() {
  local repo="$1" branch="$2" existing_pr="$3" has_diff="$4"
  local run_key="$5" input_json="$6" pr_title="$7" body_file="$8"
  local render_callback="$9" update_script="${10}" resolve_script="${11}" link_script="${12}"
  local verify_json="${13}" pr_url skip_notice

  if [[ "$has_diff" -eq 0 ]]; then
    python3 "$(dirname "${BASH_SOURCE[0]}")/validate-no-diff-fix.py" \
      "$input_json" "$verify_json" || return 1
  fi

  if [[ "$has_diff" -eq 1 ]]; then
    git push -u origin "$branch"
  elif [[ -z "$existing_pr" ]]; then
    skip_notice="(skipped — all actionable findings verified cant_reproduce)"
    bash "$update_script" "$run_key" "$skip_notice" "$input_json"
    fix_phase_log "publish"
    return 0
  fi

  if [[ -n "$existing_pr" ]]; then
    echo "Open draft PR already exists: #${existing_pr}"
    pr_url="$(gh pr view "$existing_pr" -R "$repo" --json url --jq .url)"
    if [[ "$has_diff" -eq 0 ]]; then
      echo "::notice::No code changes; leaving draft PR #${existing_pr} body unchanged"
      batch_fix_link_pr_to_umbrella \
        "$repo" "$pr_url" "$run_key" "$input_json" "$resolve_script" "$link_script"
      bash "$update_script" "$run_key" "$pr_url" "$input_json"
      fix_phase_log "publish"
      return 0
    fi
    "$render_callback"
    gh pr edit "$existing_pr" -R "$repo" --body-file "$body_file"
  else
    "$render_callback"
    pr_url="$(gh pr create -R "$repo" \
      --base main --head "$branch" --draft --title "$pr_title" --body-file "$body_file")"
    echo "Created draft PR: ${pr_url}"
  fi

  batch_fix_link_pr_to_umbrella \
    "$repo" "$pr_url" "$run_key" "$input_json" "$resolve_script" "$link_script"
  bash "$update_script" "$run_key" "$pr_url" "$input_json"
  fix_phase_log "publish"
}
