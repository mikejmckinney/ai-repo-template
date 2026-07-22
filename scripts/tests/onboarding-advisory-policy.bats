#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "template ships versioned onboarding seed state" {
  run jq -e '
    .schema_version == 1 and
    .template == "mikejmckinney/ai-repo-template" and
    .status == "template-seed"
  ' "$REPO_ROOT/.context/onboarding-state.json"

  [ "$status" -eq 0 ]
  grep -qF '  ".context/onboarding-state.json"' "$REPO_ROOT/install.sh"
}

@test "installer seeds only fresh repositories and preserves legacy missing state" {
  fixture="$(mktemp -d)"
  dotfiles="$fixture/dotfiles"
  fresh="$fixture/fresh"
  legacy="$fixture/legacy"
  mkdir -p "$dotfiles/.context" "$fresh" "$legacy"
  cp "$REPO_ROOT/.context/onboarding-state.json" "$dotfiles/.context/onboarding-state.json"
  git -C "$fresh" init -q
  git -C "$legacy" init -q
  git -C "$legacy" config user.email test@example.com
  git -C "$legacy" config user.name test
  printf '%s\n' '# Existing project' >"$legacy/README.md"
  git -C "$legacy" add README.md
  git -C "$legacy" commit -qm 'existing project'

  run env PATH=/usr/bin:/bin DOTFILES="$dotfiles" WORKSPACE="$fresh" \
    /bin/bash "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -f "$fresh/.context/onboarding-state.json" ]

  run env PATH=/usr/bin:/bin DOTFILES="$dotfiles" WORKSPACE="$legacy" \
    /bin/bash "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$legacy/.context/onboarding-state.json" ]
  [[ "$output" == *"preserving legacy missing-state migration"* ]]

  rm -rf "$fixture"
}

@test "required-file checks accept the documented legacy missing-state path" {
  check="$REPO_ROOT/scripts/checks/010-required-files.sh"

  run grep -qF '  ".context/onboarding-state.json"' "$check"
  [ "$status" -ne 0 ]
  grep -qF 'legacy derived repository has no onboarding state' "$check"
  grep -qF 'warn ' "$check"
}

@test "active onboarding surfaces do not use placeholder replacement semantics" {
  for path in \
    .agents/skills/repo-onboarding/scripts/classify-mode.sh \
    .agents/skills/repo-onboarding/scripts/validate-onboarding.sh \
    .agents/skills/repo-onboarding/SKILL.md \
    .github/ISSUE_TEMPLATE/agent_init.md \
    scripts/verify-env.sh \
    README.md \
    AI_REPO_GUIDE.md \
    docs/FAQ.md; do
    run grep -q 'TEMPLATE_PLACEHOLDER' "$REPO_ROOT/$path"
    [ "$status" -ne 0 ]
  done
}

@test "agent policy requires unfamiliar-repository onboarding with recovery precedence" {
  run python3 - "$REPO_ROOT/AGENTS.md" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert "AGENTS_MD_VERSION: 37" in text
assert "unfamiliar repository" in text
assert "repo-onboarding" in text
assert "session-recovery" in text
assert "onboarding receipt" in text
assert "Do not rerun onboarding" in text
PY

  [ "$status" -eq 0 ]
}

@test "agent policy makes advisory normal, current-head aware, and non-blocking" {
  run python3 - "$REPO_ROOT/AGENTS.md" "$REPO_ROOT/docs/decisions/adr-031-agent-model-roi-benchmark-policy.md" <<'PY'
import sys
from pathlib import Path

agents = Path(sys.argv[1]).read_text(encoding="utf-8")
adr = Path(sys.argv[2]).read_text(encoding="utf-8")
for phrase in (
    "every eligible same-repository task PR",
    "ai-review:live",
    "current PR head",
    "independently verify",
    "without waiting",
    "never a merge gate",
):
    assert phrase in agents, phrase
assert "normal agent practice" in adr
assert "cannot mutate or block the PR" in adr
PY

  [ "$status" -eq 0 ]
}

@test "interactive and automated OpenCode configurations explicitly disable LSP" {
  for path in \
    .opencode/opencode.json \
    .github/agent-runtime/base.json \
    .github/agent-runtime/review.json \
    .github/agent-runtime/fix.json; do
    run jq -e '.lsp == false' "$REPO_ROOT/$path"
    [ "$status" -eq 0 ]
  done
}

@test "advisory snapshot contract remains SHA-bearing and non-blocking" {
  grep -q 'Head: `<sha>`' "$REPO_ROOT/.github/prompts/pr-advisory-review.md"
  grep -q 'Provider: `<opencode|cursor|gemini|antigravity>`' "$REPO_ROOT/.github/prompts/pr-advisory-review.md"
  grep -q 'cancel-in-progress: true' "$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
  grep -q 'ai-review:live' "$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
}

@test "verify-env ignores placeholder marker text" {
  run grep -q 'TEMPLATE_PLACEHOLDER' "$REPO_ROOT/scripts/verify-env.sh"
  [ "$status" -ne 0 ]
}
