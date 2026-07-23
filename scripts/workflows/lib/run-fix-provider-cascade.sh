#!/usr/bin/env bash

run_fix_provider_cascade() {
  local mode="$1" prompt_file="$2" output_file="$3" repo_root="$4"
  local advisory_dir="$5" workdir="$6" lib_dir="$7" gemini_apply_callback="$8"
  local batch_json="$9" verify_relative_path="${10}"
  local verify_command="${FIX_PROVIDER_VERIFY_COMMAND:-./test.sh}"
  local attempt_root active_worktree attempt_output patch_file provider
  local -a provider_candidates=()

  mapfile -t provider_candidates < <(list_advisory_providers "$mode")
  if [[ ${#provider_candidates[@]} -eq 0 ]]; then
    echo "::error::No fix provider configured" >&2
    return 1
  fi

  attempt_root="$(mktemp -d)"
  for provider in "${provider_candidates[@]}"; do
    active_worktree="$attempt_root/worktree-${RANDOM}"
    attempt_output="$attempt_root/output-${RANDOM}.txt"
    patch_file="$attempt_root/attempt.patch"
    git -C "$repo_root" worktree add --detach "$active_worktree" HEAD >/dev/null

    if (
      cd "$active_worktree"
      OPENCODE_FIX_MODE=true \
        OPENCODE_FIX_VERIFY_COMMAND=true \
        CURSOR_FIX_VERIFY_COMMAND=true \
        invoke_advisory_llm "$prompt_file" "$attempt_output" "$provider" \
        "$advisory_dir" "$active_worktree" "$workdir" "$lib_dir"
      if [[ "$provider" == "gemini" ]]; then
        "$gemini_apply_callback" "$attempt_output" "$active_worktree"
      fi
    ) && (
      cd "$active_worktree"
      env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
        -u OPENCODE_GITHUB_TOKEN -u OPENCODE_AUTH_CONTENT -u OPENAI_API_KEY \
        -u OPENROUTER_API_KEY -u CURSOR_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY \
        bash -c "$verify_command"
      git add -N -- . >/dev/null 2>&1 || true
      validation_mode=--no-substantive-diff
      while IFS= read -r changed_path; do
        if [[ "$changed_path" != "$verify_relative_path" && "$changed_path" != .artifacts/* ]]; then
          validation_mode=--substantive-diff
          break
        fi
      done < <(git diff HEAD --name-only)
      python3 "$lib_dir/validate-fix-verification.py" \
        "$batch_json" "$active_worktree/$verify_relative_path" "$validation_mode"
    ); then
      if ! git -C "$active_worktree" add -N -- . >/dev/null 2>&1; then
        echo "::warning::Fix worktree contains no paths to stage for diff detection" >&2
      fi
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

    echo "::warning::Discarding failed or unverified fix provider ${provider}" >&2
    if ! git -C "$repo_root" worktree remove --force "$active_worktree" >/dev/null 2>&1; then
      echo "::warning::Could not remove fix worktree: $active_worktree" >&2
    fi
  done

  rm -rf "$attempt_root"
  echo "::error::Fix provider cascade exhausted" >&2
  return 1
}
