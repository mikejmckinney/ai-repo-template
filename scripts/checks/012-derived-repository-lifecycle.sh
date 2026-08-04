#!/usr/bin/env bash
# Verify the distributed template transitions cleanly from seed to complete.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking derived repository lifecycle..."

  if [[ "${DERIVED_LIFECYCLE_INNER:-}" == 1 ]]; then
    pass "derived lifecycle recursion guard active"
    return 0
  fi

  lifecycle_fixture="$(mktemp -d "${TMPDIR:-/tmp}/derived-lifecycle.XXXXXX")"
  lifecycle_repo="$lifecycle_fixture/product"
  mkdir -p "$lifecycle_repo"
  if git ls-files -z \
    | tar --null -cf - -T - \
    | tar -xf - -C "$lifecycle_repo"; then
    git -C "$lifecycle_repo" init -q
    git -C "$lifecycle_repo" config user.email test@example.com
    git -C "$lifecycle_repo" config user.name Test
    git -C "$lifecycle_repo" remote add origin https://github.com/example/product.git
    git -C "$lifecycle_repo" add -A
    git -C "$lifecycle_repo" commit -qm "seed template"

    seed_classification="$("$lifecycle_repo/.agents/skills/repo-onboarding/scripts/classify-mode.sh" --repo "$lifecycle_repo")"
    if [[ "$(jq -r .mode <<<"$seed_classification")" == template-seed &&
    "$(jq -r .requires_onboarding <<<"$seed_classification")" == true ]]; then
      pass "copied template starts in template-seed mode"
    else
      fail "copied template must start in template-seed mode"
    fi

    jq '.status = "complete"' "$lifecycle_repo/.context/onboarding-state.json" \
      >"$lifecycle_fixture/state.json"
    mv "$lifecycle_fixture/state.json" "$lifecycle_repo/.context/onboarding-state.json"
    printf '# Product Roadmap\n\nProject-owned milestones.\n' >"$lifecycle_repo/.context/roadmap.md"
    printf "# Product Context\n\n**Project Name**: \`product\`\n" >"$lifecycle_repo/.context/00_INDEX.md"
    git -C "$lifecycle_repo" add .context/onboarding-state.json .context/roadmap.md .context/00_INDEX.md
    git -C "$lifecycle_repo" commit -qm "complete onboarding"

    complete_classification="$("$lifecycle_repo/.agents/skills/repo-onboarding/scripts/classify-mode.sh" --repo "$lifecycle_repo")"
    if [[ "$(jq -r .mode <<<"$complete_classification")" == complete &&
    "$(jq -r .requires_onboarding <<<"$complete_classification")" == false ]]; then
      pass "completed derived repository classifies as complete"
    else
      fail "completed derived repository must classify as complete"
    fi

    if "$lifecycle_repo/.agents/skills/repo-onboarding/scripts/validate-onboarding.sh" \
      --repo "$lifecycle_repo" >/dev/null; then
      pass "completed derived repository passes onboarding validation"
    else
      fail "completed derived repository failed onboarding validation"
    fi

    if (cd "$lifecycle_repo" && DERIVED_LIFECYCLE_INNER=1 ./test.sh) >/dev/null; then
      pass "completed derived repository passes test.sh"
    else
      fail "completed derived repository failed test.sh"
    fi

  else
    fail "could not copy tracked template files for lifecycle verification"
  fi
  rm -rf "$lifecycle_fixture"
  echo ""
  return 0
fi

echo "012-derived-repository-lifecycle.sh is sourced by test.sh only" >&2
exit 1
