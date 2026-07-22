#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  README="$REPO_ROOT/README.md"
}

@test "README gives first-time evaluators an explicit fit decision" {
  grep -q '^## The problem this solves$' "$README"
  grep -q '^## Good fit when$' "$README"
  grep -q '^## Not the right fit when$' "$README"
  grep -qi 'README.md.*human' "$README"
  grep -q 'AGENTS.md.*operating contract' "$README"
  grep -q 'AI_REPO_GUIDE.md.*agent' "$README"
}

@test "README includes accessible static hero and six-journey tour" {
  grep -Fq '![Repository lifecycle from intent through verified change and learning](docs/media/readme/repository-lifecycle.svg)' "$README"
  grep -Fq '![Six repository journeys: ownership, onboarding, continuity, review, proof, and learning](docs/media/readme/feature-tour.svg)' "$README"

  for journey in \
    'One owner for every instruction' \
    'Onboard from repository evidence' \
    'Resume from GitHub state' \
    'Separate merge gates from advice' \
    'Prove outcomes in a sandbox' \
    'Learn after merge'; do
    grep -Fq "$journey" "$README"
  done

  for asset in repository-lifecycle.svg feature-tour.svg; do
    grep -q '<title>' "$REPO_ROOT/docs/media/readme/$asset"
    grep -q '<desc>' "$REPO_ROOT/docs/media/readme/$asset"
  done
}

@test "README comparison is dated and sourced without inferred negatives" {
  grep -Fq 'Evaluated: 2026-07-22' "$README"
  grep -Fq 'https://github.com/github/spec-kit' "$README"
  grep -Fq 'https://github.com/bmad-code-org/BMAD-METHOD' "$README"
  grep -Fq 'https://github.com/Priivacy-ai/spec-kitty' "$README"
  grep -Eq 'Not stated|Not evaluated' "$README"
}

@test "README defers video behind a comprehension gate" {
  grep -Fq 'Video is intentionally deferred' "$README"
  grep -Fq 'temporal misunderstanding' "$README"
}
