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

write_state() {
  local repo="$1" status="$2" schema_version="${3:-1}"
  jq -n \
    --argjson schema_version "$schema_version" \
    --arg status "$status" \
    '{schema_version: $schema_version, template: "mikejmckinney/ai-repo-template", status: $status}' \
    >"$repo/.context/onboarding-state.json"
}

@test "onboarding entrypoint scripts are executable" {
  [ -x "$SKILL_ROOT/scripts/classify-mode.sh" ]
  [ -x "$SKILL_ROOT/scripts/validate-onboarding.sh" ]
}

@test "template-seed onboarding runs project setup before lifecycle completion" {
  reference="$SKILL_ROOT/references/template-seed.md"
  setup_line=$(grep -n -m1 'scripts/setup\.sh' "$reference" | cut -d: -f1)
  complete_line=$(grep -n 'status: "complete"' "$reference" | cut -d: -f1)

  [ -n "$setup_line" ]
  [ -n "$complete_line" ]
  [ "$setup_line" -lt "$complete_line" ]
}

@test "routine repository orientation does not run project setup" {
  run grep -F 'Do not run `scripts/setup.sh` for `ai-repo-template` or `complete` orientation.' \
    "$SKILL_ROOT/SKILL.md"

  [ "$status" -eq 0 ]
}

@test "template-seed setup failure leaves onboarding incomplete" {
  run grep -F 'If setup fails, stop and leave lifecycle state as `template-seed`.' \
    "$SKILL_ROOT/references/template-seed.md"

  [ "$status" -eq 0 ]
}

@test "classifier chooses ai-repo-template for the canonical repository regardless of state" {
  repo=$(make_repo template)
  git -C "$repo" remote add origin git@github.com:mikejmckinney/ai-repo-template.git
  write_state "$repo" template-seed
  before=$(git -C "$repo" status --porcelain=v1)

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = ai-repo-template ]
  [ "$(jq -r '.requires_onboarding' <<<"$output")" = false ]
  [ "$(git -C "$repo" status --porcelain=v1)" = "$before" ]
}

@test "classifier normalizes canonical GitHub URL casing and trailing slashes" {
  index=0
  for remote in \
    https://GitHub.com/MikeJMcKinney/AI-Repo-Template/ \
    https://github.com/mikejmckinney/ai-repo-template.git/; do
    index=$((index + 1))
    repo=$(make_repo "canonical-variant-$index")
    git -C "$repo" remote add origin "$remote"
    write_state "$repo" template-seed

    run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.mode' <<<"$output")" = ai-repo-template ]
    [ "$(jq -r '.requires_onboarding' <<<"$output")" = false ]
  done
}

@test "classifier does not treat same-named repositories under another owner as canonical" {
  for name in ai-repo-template dotfiles; do
    repo=$(make_repo "derived-$name")
    git -C "$repo" remote add origin "git@github.com:example/$name.git"
    write_state "$repo" template-seed

    run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.mode' <<<"$output")" = template-seed ]
    [ "$(jq -r '.requires_onboarding' <<<"$output")" = true ]
  done
}

@test "classifier does not trust canonical paths on unrecognized hosts or local remotes" {
  index=0
  for remote in \
    https://gitlab.example/mikejmckinney/ai-repo-template.git \
    /tmp/mikejmckinney/ai-repo-template.git; do
    index=$((index + 1))
    repo=$(make_repo "untrusted-$index")
    git -C "$repo" remote add origin "$remote"
    write_state "$repo" template-seed

    run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.mode' <<<"$output")" = template-seed ]
    [ "$(jq -r '.requires_onboarding' <<<"$output")" = true ]
  done
}

@test "classifier honors lifecycle state when origin is unavailable" {
  repo=$(make_repo ai-repo-template)
  write_state "$repo" template-seed

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = template-seed ]
  [ "$(jq -r '.requires_onboarding' <<<"$output")" = true ]
}

@test "classifier chooses template-seed for a derived repository with seed state" {
  repo=$(make_repo derived-seed)
  git -C "$repo" remote add origin git@github.com:example/product.git
  write_state "$repo" template-seed

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = template-seed ]
  [ "$(jq -r '.requires_onboarding' <<<"$output")" = true ]
  [ "$(jq -r '.warnings | length' <<<"$output")" -eq 0 ]
}

@test "classifier chooses complete for an explicitly onboarded repository" {
  repo=$(make_repo customized)
  git -C "$repo" remote add origin git@github.com:example/product.git
  write_state "$repo" complete

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = complete ]
  [ "$(jq -r '.requires_onboarding' <<<"$output")" = false ]
  [ "$(jq -r '.warnings | length' <<<"$output")" -eq 0 ]
}

@test "classifier treats missing state as legacy complete with a migration warning" {
  repo=$(make_repo legacy)
  git -C "$repo" remote add origin git@github.com:example/product.git

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = complete ]
  [ "$(jq -r '.requires_onboarding' <<<"$output")" = false ]
  [ "$(jq -r '.warnings | length' <<<"$output")" -eq 1 ]
  [[ "$(jq -r '.warnings[0]' <<<"$output")" == *"onboarding-state.json"* ]]
}

@test "placeholder text does not change legacy derived classification" {
  repo=$(make_repo legacy-placeholders)
  git -C "$repo" remote add origin git@github.com:example/product.git
  printf '%s\n' 'TEMPLATE_PLACEHOLDER' >>"$repo/README.md"
  printf '%s\n' 'contact_links: PLEASE_UPDATE_THIS/URL' >"$repo/.github/ISSUE_TEMPLATE/config.yml"
  printf '%s\n' '**Project Name**: `ai-repo-template`' >"$repo/.context/00_INDEX.md"

  run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = complete ]
  [ "$(jq -r '.warnings | length' <<<"$output")" -eq 1 ]
}

@test "classifier rejects malformed or unsupported onboarding state" {
  for fixture in malformed schema status; do
    repo=$(make_repo "$fixture")
    git -C "$repo" remote add origin git@github.com:example/product.git
    case "$fixture" in
      malformed) printf '%s\n' '{not-json' >"$repo/.context/onboarding-state.json" ;;
      schema) write_state "$repo" complete 2 ;;
      status) write_state "$repo" unknown ;;
    esac

    run "$SKILL_ROOT/scripts/classify-mode.sh" --repo "$repo"

    [ "$status" -ne 0 ]
    [[ "$output" == *"onboarding state"* ]]
  done
}

@test "validator reports template-seed as requiring authorized onboarding without changing files" {
  repo=$(make_repo validation-seed)
  write_state "$repo" template-seed
  before=$(git -C "$repo" status --porcelain=v1)

  run "$SKILL_ROOT/scripts/validate-onboarding.sh" --repo "$repo"

  [ "$status" -ne 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = template-seed ]
  [ "$(jq -r '.stable' <<<"$output")" = false ]
  [ "$(jq -r '.blocking_findings | length' <<<"$output")" -ge 1 ]
  [ "$(git -C "$repo" status --porcelain=v1)" = "$before" ]
}

@test "validator accepts a complete repository and reports optional warnings" {
  repo=$(make_repo stable)
  write_state "$repo" complete

  run "$SKILL_ROOT/scripts/validate-onboarding.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = complete ]
  [ "$(jq -r '.stable' <<<"$output")" = true ]
}

@test "authorized seed onboarding transitions to complete before final validation" {
  repo=$(make_repo transition)
  write_state "$repo" template-seed

  run "$SKILL_ROOT/scripts/validate-onboarding.sh" --repo "$repo"
  [ "$status" -ne 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = template-seed ]

  write_state "$repo" complete
  run "$SKILL_ROOT/scripts/validate-onboarding.sh" --repo "$repo"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.mode' <<<"$output")" = complete ]
  [ "$(jq -r '.stable' <<<"$output")" = true ]
}
