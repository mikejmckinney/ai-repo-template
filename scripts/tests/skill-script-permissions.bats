#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

@test "repository-owned skill shell scripts are executable" {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  failures=()

  mapfile -t scripts < <(
    while IFS= read -r destination; do
      find "$repo_root/$destination" -type f -path '*/scripts/*.sh' -print
    done < <(jq -r '.ownedSkills[].destinationPath' "$repo_root/skills-lock.json")
  )

  for script in "${scripts[@]}"; do
    [[ -x "$script" ]] || failures+=("${script#"$repo_root/"}")
  done

  if [[ ${#failures[@]} -ne 0 ]]; then
    printf 'Non-executable skill scripts:\n%s\n' "${failures[*]}" >&2
  fi
  [[ ${#failures[@]} -eq 0 ]]
}
