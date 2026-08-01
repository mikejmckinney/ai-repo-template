#!/usr/bin/env bash

run_fix_provider_cascade() {
  local mode="$1" prompt_file="$2" output_file="$3" repo_root="$4"
  local advisory_dir="$5" workdir="$6" lib_dir="$7" gemini_apply_callback="$8"
  local batch_json="$9" verify_relative_path="${10}"
  local verify_command="${FIX_PROVIDER_VERIFY_COMMAND:-./test.sh}"
  local baseline_verify_command="${FIX_PROVIDER_BASELINE_VERIFY_COMMAND:-$verify_command}"
  local attempt_root baseline_worktree active_worktree attempt_output patch_file provider
  local batch_source batch_relative_path attempt_batch_json canonical_repo
  local baseline_status provider_status application_status registration_status
  local verification_status fix_verification_status outcome_evidence_status
  local failed_stage validation_mode
  local -a provider_candidates=()

  mapfile -t provider_candidates < <(list_advisory_providers "$mode")
  if [[ ${#provider_candidates[@]} -eq 0 ]]; then
    echo "::error::No fix provider configured" >&2
    return 1
  fi

  canonical_repo="$(realpath "$repo_root")"
  if [[ "$batch_json" == /* ]]; then
    batch_source="$(realpath "$batch_json")"
  else
    batch_source="$(realpath "$canonical_repo/$batch_json")"
  fi
  if [[ "$batch_source" == "$canonical_repo/"* ]]; then
    batch_relative_path="${batch_source#"$canonical_repo"/}"
  else
    batch_relative_path=".artifacts/fix-provider-input.json"
  fi

  attempt_root="$(mktemp -d)"
  baseline_worktree="$attempt_root/baseline"
  if ! git -C "$repo_root" worktree add --detach "$baseline_worktree" HEAD >/dev/null; then
    rm -rf "$attempt_root"
    echo "::error::Could not create baseline verification worktree" >&2
    return 1
  fi
  baseline_status=0
  (
    cd "$baseline_worktree"
    env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
      -u OPENCODE_GITHUB_TOKEN -u OPENCODE_AUTH_CONTENT -u OPENAI_API_KEY \
      -u OPENROUTER_API_KEY -u CURSOR_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY \
      bash -c "$baseline_verify_command"
  ) || baseline_status=$?
  if ! git -C "$repo_root" worktree remove --force "$baseline_worktree" >/dev/null 2>&1; then
    echo "::warning::Could not remove baseline worktree: $baseline_worktree" >&2
  fi
  echo "Baseline verification status: $baseline_status" >&2

  for provider in "${provider_candidates[@]}"; do
    active_worktree="$attempt_root/worktree-${RANDOM}"
    attempt_output="$attempt_root/output-${RANDOM}.txt"
    patch_file="$attempt_root/attempt.patch"
    git -C "$repo_root" worktree add --detach "$active_worktree" HEAD >/dev/null
    attempt_batch_json="$active_worktree/$batch_relative_path"
    mkdir -p "$(dirname "$attempt_batch_json")"
    cp -- "$batch_source" "$attempt_batch_json"

    failed_stage=""
    provider_status=0
    (
      cd "$active_worktree"
      FIX_PROVIDER_BATCH_JSON="$attempt_batch_json" \
        OPENCODE_FIX_MODE=true \
        OPENCODE_FIX_VERIFY_COMMAND=true \
        CURSOR_FIX_VERIFY_COMMAND=true \
        invoke_advisory_llm "$prompt_file" "$attempt_output" "$provider" \
        "$advisory_dir" "$active_worktree" "$workdir" "$lib_dir"
    ) || provider_status=$?
    if ((provider_status != 0)); then
      failed_stage="provider invocation"
    fi

    if [[ -z "$failed_stage" && "$provider" == "gemini" ]]; then
      application_status=0
      (
        cd "$active_worktree"
        "$gemini_apply_callback" "$attempt_output" "$active_worktree"
      ) || application_status=$?
      if ((application_status != 0)); then
        failed_stage="Gemini application"
      fi
    fi

    if [[ -z "$failed_stage" ]]; then
      registration_status=0
      git -C "$active_worktree" add -N -- . >/dev/null 2>&1 || registration_status=$?
      if ((registration_status != 0)); then
        failed_stage="candidate path registration"
      fi
    fi

    if [[ -z "$failed_stage" ]]; then
      verification_status=0
      (
        cd "$active_worktree"
        env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
          -u OPENCODE_GITHUB_TOKEN -u OPENCODE_AUTH_CONTENT -u OPENAI_API_KEY \
          -u OPENROUTER_API_KEY -u CURSOR_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY \
          bash -c "$verify_command"
      ) || verification_status=$?
      echo "Candidate verification status for ${provider}: $verification_status" >&2
      if ((verification_status != 0)); then
        failed_stage="deterministic verification"
      fi
    fi

    if [[ -z "$failed_stage" ]]; then
      validation_mode=--no-substantive-diff
      while IFS= read -r changed_path; do
        if [[ "$changed_path" != "$verify_relative_path" && "$changed_path" != .artifacts/* ]]; then
          validation_mode=--substantive-diff
          break
        fi
      done < <(git -C "$active_worktree" diff HEAD --name-only)

      fix_verification_status=0
      python3 "$lib_dir/validate-fix-verification.py" \
        "$attempt_batch_json" "$active_worktree/$verify_relative_path" "$validation_mode" \
        || fix_verification_status=$?
      if ((fix_verification_status != 0)); then
        failed_stage="fix verification"
      fi
    fi

    if [[ -z "$failed_stage" ]]; then
      outcome_evidence_status=0
      python3 "$lib_dir/../../validate-outcome-evidence.py" \
        "$active_worktree/$verify_relative_path" --from-fix-verify \
        || outcome_evidence_status=$?
      if ((outcome_evidence_status != 0)); then
        failed_stage="outcome evidence"
      fi
    fi

    if [[ -z "$failed_stage" ]]; then
      git -C "$active_worktree" diff --binary --full-index >"$patch_file"
      if [[ -s "$patch_file" ]]; then
        git -C "$repo_root" apply "$patch_file"
      fi
      cp "$attempt_output" "$output_file"
      git -C "$repo_root" worktree remove --force "$active_worktree" >/dev/null
      rm -rf "$attempt_root"
      echo "Fix provider ${provider} promoted after verification" >&2
      return 0
    fi

    echo "::warning::Discarding fix provider ${provider} after failed ${failed_stage}" >&2
    if ! git -C "$repo_root" worktree remove --force "$active_worktree" >/dev/null 2>&1; then
      echo "::warning::Could not remove fix worktree: $active_worktree" >&2
    fi
  done

  rm -rf "$attempt_root"
  echo "::error::Fix provider cascade exhausted" >&2
  return 1
}
