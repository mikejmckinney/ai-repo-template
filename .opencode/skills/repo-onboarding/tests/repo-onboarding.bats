#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  SKILL_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/repo-onboarding-test.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

make_repo() {
  local name="$1" repo="$TEST_ROOT/$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name test
  printf '%s\n' '# Project' >"$repo/README.md"
  printf '%s\n' '# Guide' >"$repo/AI_REPO_GUIDE.md"
  mkdir -p "$repo/.context" "$repo/.github/ISSUE_TEMPLATE"
  printf '%s\n' '# Index' >"$repo/.context/00_INDEX.md"
  printf '%s\n' 'blank_issues_enabled: true' >"$repo/.github/ISSUE_TEMPLATE/config.yml"
  git -C "$repo" add .
  git -C "$repo" commit -qm "Initialize $name"
  printf '%s' "$repo"
}

@test "classifier chooses Mode A for the template even with placeholder signals" {
  repo=$(make_repo template)
  git -C "$repo" remote add origin git@github.com:mikejmckinney/ai-repo-template.git
  printf '%s\n' 'TEMPLATE_PLACEHOLDER' >>"$repo/README.md"
  before=$(git -C "$repo" status --porcelain=v1)

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = A ]
  [ "$(jq -r '.requires_bootstrap' <<<"$output")" = false ]
  [ "$(git -C "$repo" status --porcelain=v1)" = "$before" ]
}

@test "classifier chooses Mode B for a derived repository with bootstrap signals" {
  repo=$(make_repo derived-stub)
  git -C "$repo" remote add origin git@github.com:example/product.git
  printf '%s\n' 'TEMPLATE_PLACEHOLDER' >>"$repo/AI_REPO_GUIDE.md"
  printf '%s\n' 'contact_links: PLEASE_UPDATE_THIS/URL' >"$repo/.github/ISSUE_TEMPLATE/config.yml"

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = B ]
  [ "$(jq -r '.requires_bootstrap' <<<"$output")" = true ]
  [ "$(jq -r '.signals | length' <<<"$output")" -ge 2 ]
}

@test "classifier chooses Mode C for an already customized repository" {
  repo=$(make_repo customized)
  git -C "$repo" remote add origin git@github.com:example/product.git
  printf '%s\n' "- Derived from \`ai-repo-template\`; send feedback upstream." >>"$repo/.context/00_INDEX.md"

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = C ]
  [ "$(jq -r '.signals | length' <<<"$output")" -eq 0 ]
}

@test "validator reports Mode B blockers without changing files" {
  repo=$(make_repo validation-stub)
  printf '%s\n' 'TEMPLATE_PLACEHOLDER' >>"$repo/README.md"
  before=$(git -C "$repo" status --porcelain=v1)

  run "$SKILL_ROOT/scripts/validate-onboarding.sh" --repo "$repo"

  [ "$status" -ne 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = B ]
  [ "$(jq -r '.stable' <<<"$output")" = false ]
  [ "$(jq -r '.blocking_findings | length' <<<"$output")" -ge 1 ]
  [ "$(git -C "$repo" status --porcelain=v1)" = "$before" ]
}

@test "validator accepts a customized repository and reports optional warnings" {
  repo=$(make_repo stable)

  run "$SKILL_ROOT/scripts/validate-onboarding.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = C ]
  [ "$(jq -r '.stable' <<<"$output")" = true ]
}
