#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

@test "vendored skill shell scripts are executable" {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  failures=()

  while IFS= read -r script; do
    [[ -x "$script" ]] || failures+=("${script#"$repo_root/"}")
  done < <(find "$repo_root/.agents/skills" -type f -path '*/scripts/*.sh' -print | sort)

  if [[ ${#failures[@]} -ne 0 ]]; then
    printf 'Non-executable skill scripts:\n%s\n' "${failures[*]}" >&2
  fi
  [[ ${#failures[@]} -eq 0 ]]
}
