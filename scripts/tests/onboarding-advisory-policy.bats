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
  fixture="$(mktemp -d)"
  repo="$fixture/legacy"
  mkdir -p "$repo"

  while IFS= read -r path; do
    mkdir -p "$repo/$(dirname "$path")"
    : >"$repo/$path"
  done < <(python3 - "$check" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
block = text.split("REQUIRED_FILES=(", 1)[1].split(")", 1)[0]
for path in re.findall(r'^\s+"([^"]+)"$', block, re.MULTILINE):
    print(path)
PY
  )
  printf '@AGENTS.md\n' >"$repo/CLAUDE.md"
  mkdir -p "$repo/.agents/skills/repo-onboarding/scripts"
  cp "$REPO_ROOT/.agents/skills/repo-onboarding/scripts/classify-mode.sh" \
    "$repo/.agents/skills/repo-onboarding/scripts/classify-mode.sh"
  chmod +x "$repo/.agents/skills/repo-onboarding/scripts/classify-mode.sh"
  git -C "$repo" init -q
  git -C "$repo" remote add origin git@github.com:example/product.git

  run bash -c '
    cd "$1"
    PASS=0 FAIL=0 WARN=0
    pass() { PASS=$((PASS + 1)); }
    fail() { FAIL=$((FAIL + 1)); }
    warn() { WARN=$((WARN + 1)); }
    source "$2"
    printf "pass=%s fail=%s warn=%s\n" "$PASS" "$FAIL" "$WARN"
  ' _ "$repo" "$check"

  [ "$status" -eq 0 ]
  [[ "$output" == *"fail=0 warn=1"* ]]
  rm -rf "$fixture"
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
assert "AGENTS_MD_VERSION: 38" in text
assert "unfamiliar repository" in text
assert "repo-onboarding" in text
assert "session-recovery" in text
assert "onboarding receipt" in text
assert "Do not rerun onboarding" in text
PY

  [ "$status" -eq 0 ]
}

@test "initialization follows classifier output instead of forcing template-seed" {
  template="$REPO_ROOT/.github/ISSUE_TEMPLATE/agent_init.md"

  run python3 - "$template" <<'PY'
import sys
from pathlib import Path

text = " ".join(Path(sys.argv[1]).read_text(encoding="utf-8").split())
assert "follow its classified mode" in text
assert "only when the classifier returns `template-seed`" in text
assert "skill in `template-seed` mode" not in text
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
  grep -q 'Provider: `<provider> / <model-or-agent>`' "$REPO_ROOT/.github/prompts/pr-advisory-review.md"
  grep -q 'No findings identified at this head' "$REPO_ROOT/.github/prompts/pr-advisory-review.md"
  grep -q 'cancel-in-progress: true' "$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
  grep -q 'ai-review:live' "$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
  grep -q 'GITHUB_EVENT_ACTION:' "$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
  grep -q 'select-advisory-range.py' "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh"
  grep -q 'normalize-advisory-snapshot.py' "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh"
  for path in \
    scripts/workflows/lib/run-opencode.mjs \
    scripts/workflows/advisory-review/run-advisory-cursor.mjs \
    scripts/workflows/advisory-review/run-advisory-gemini.py \
    scripts/workflows/advisory-review/run-advisory-antigravity.py; do
    grep -q 'ADVISORY_PROVIDER_METADATA_FILE' "$REPO_ROOT/$path"
  done
}

@test "verify-env ignores placeholder marker text" {
  run grep -q 'TEMPLATE_PLACEHOLDER' "$REPO_ROOT/scripts/verify-env.sh"
  [ "$status" -ne 0 ]
}

@test "unused operational scaffolding is absent" {
  ! grep -q 'PLEASE_UPDATE_THIS' "$REPO_ROOT/.github/ISSUE_TEMPLATE/config.yml"
  ! grep -q 'Run tests (placeholder)' "$REPO_ROOT/.github/workflows/ci-tests.yml"
  ! grep -q 'CUSTOMIZE THIS SECTION FOR YOUR TECH STACK' "$REPO_ROOT/.github/workflows/ci-tests.yml"
  ! grep -q '&lt;N&gt;\|<tool + config path>\|<framework + command>' "$REPO_ROOT/AGENTS.md"
  [ ! -e "$REPO_ROOT/scripts/db-reset.sh" ]
  ! grep -q 'Database Setup\|database step is currently a placeholder' \
    "$REPO_ROOT/scripts/setup/20-install-dependencies.sh"
}

@test "design contract is created only on demand from the canonical asset" {
  [ ! -e "$REPO_ROOT/DESIGN.md" ]
  [ -f "$REPO_ROOT/.agents/skills/repo-onboarding/assets/DESIGN.md" ]
  [ -x "$REPO_ROOT/.agents/skills/repo-onboarding/scripts/create-design-contract.sh" ]

  repo="$(mktemp -d)"
  run "$REPO_ROOT/.agents/skills/repo-onboarding/scripts/create-design-contract.sh" --repo "$repo"
  [ "$status" -eq 0 ]
  cmp -s "$REPO_ROOT/.agents/skills/repo-onboarding/assets/DESIGN.md" "$repo/DESIGN.md"
  run "$REPO_ROOT/.agents/skills/repo-onboarding/scripts/create-design-contract.sh" --repo "$repo"
  [ "$status" -ne 0 ]
  rm -rf "$repo"
}

@test "active dogfood surfaces describe the completed current phase" {
  ! grep -q 'Phase%200%3A%20Design\|Phase 0: Design' "$REPO_ROOT/README.md"
  run python3 - "$REPO_ROOT/.context/roadmap.md" "$REPO_ROOT/.context/00_INDEX.md" <<'PY'
import sys
from pathlib import Path

roadmap = Path(sys.argv[1]).read_text(encoding="utf-8")
index = Path(sys.argv[2]).read_text(encoding="utf-8")
phase7 = roadmap.split("## Phase 7:", 1)[1].split("\n---", 1)[0]
assert "**Status**: Complete" in phase7
assert "### Active Track" not in phase7
assert "Issue #279" not in roadmap
assert "Complete issue #474" not in index
assert "**Current Phase**" not in index
PY
  [ "$status" -eq 0 ]
  ! grep -q '#428 next' "$REPO_ROOT/.context/sessions/latest_summary.md"
  ! grep -q 'Optional in-progress PR advisory' "$REPO_ROOT/AI_REPO_GUIDE.md"
  ! grep -q 'Optional PR advisory' "$REPO_ROOT/.github/prompts/README.md"
}
