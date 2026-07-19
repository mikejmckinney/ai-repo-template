#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TOOL="$REPO_ROOT/scripts/skill-supply-chain.py"
  FIXTURE_ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIXTURE_ROOT/.agents/skills/acme"
  cat >"$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" <<'EOF'
---
name: acme
description: Fixture skill.
---

# Acme
EOF
}

write_lock() {
  local computed_hash="$1"
  local skill_path="${2:-skills/acme}"
  local destination_path="${3:-.agents/skills/acme}"

  jq -n \
    --arg hash "$computed_hash" \
    --arg skill_path "$skill_path" \
    --arg destination_path "$destination_path" \
    '{
      version: 2,
      skills: {
        acme: {
          source: "example/acme-skills",
          ref: "0123456789abcdef0123456789abcdef01234567",
          sourceType: "github",
          skillPath: $skill_path,
          destinationPath: $destination_path,
          hashAlgorithm: "sha256-tree-v1",
          computedHash: $hash
        }
      },
      ownedSkills: {}
    }' >"$FIXTURE_ROOT/skills-lock.json"
}

@test "package hash is deterministic and includes executable modes" {
  mkdir -p "$FIXTURE_ROOT/.agents/skills/acme/scripts"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' \
    >"$FIXTURE_ROOT/.agents/skills/acme/scripts/check.sh"

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  first_hash="$output"

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  [ "$output" = "$first_hash" ]

  chmod +x "$FIXTURE_ROOT/.agents/skills/acme/scripts/check.sh"
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  [ "$output" != "$first_hash" ]
}

@test "package hash rejects symlinks" {
  ln -s /etc/passwd "$FIXTURE_ROOT/.agents/skills/acme/escape"

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -ne 0 ]
  [[ "$output" == *"symlink"* ]]
}

@test "lock validation accepts a complete external package record" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "lock validation rejects path traversal" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output" "../escape"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"skillPath"*"traversal"* ]]
}

@test "lock validation rejects undeclared discovered skills" {
  mkdir -p "$FIXTURE_ROOT/.agents/skills/undeclared"
  cat >"$FIXTURE_ROOT/.agents/skills/undeclared/SKILL.md" <<'EOF'
---
name: undeclared
description: Not represented in the lock.
---
EOF

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"undeclared skill"*"undeclared"* ]]
}

@test "lock validation accepts explicitly repository-owned skills" {
  mkdir -p "$FIXTURE_ROOT/.agents/skills/local"
  cat >"$FIXTURE_ROOT/.agents/skills/local/SKILL.md" <<'EOF'
---
name: local
description: Repository-owned fixture.
---
EOF

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.ownedSkills.local = {destinationPath: ".agents/skills/local"}' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "lock validation rejects malformed and duplicate skill metadata" {
  mkdir -p "$FIXTURE_ROOT/.agents/skills/duplicate"
  cat >"$FIXTURE_ROOT/.agents/skills/duplicate/SKILL.md" <<'EOF'
---
name: acme
description: Duplicate name.
---
EOF

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.ownedSkills.duplicate = {destinationPath: ".agents/skills/duplicate"}' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"duplicate skill name"*"acme"* ]]
}

@test "source-scoped check reports changes without modifying the repository" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  upstream="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$upstream/skills/acme"
  cat >"$upstream/skills/acme/SKILL.md" <<'EOF'
---
name: acme
description: Updated fixture skill.
---

# Updated Acme
EOF
  before_lock="$(sha256sum "$FIXTURE_ROOT/skills-lock.json")"
  before_skill="$(sha256sum "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md")"

  run python3 "$TOOL" check \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"
  [ "$status" -eq 0 ]
  run jq -e '.status == "success" and .changed == true and .packages == ["acme"]' <<<"$output"
  [ "$status" -eq 0 ]
  [ "$(sha256sum "$FIXTURE_ROOT/skills-lock.json")" = "$before_lock" ]
  [ "$(sha256sum "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md")" = "$before_skill" ]
}

@test "source-scoped update replaces declared packages and is idempotent" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  upstream="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$upstream/skills/acme"
  cat >"$upstream/skills/acme/SKILL.md" <<'EOF'
---
name: acme
description: Updated fixture skill.
---

# Updated Acme
EOF
  target_ref="1111111111111111111111111111111111111111"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "$target_ref"
  [ "$status" -eq 0 ]
  run jq -e --arg ref "$target_ref" \
    '.status == "success" and .changed == true and .newRef == $ref' <<<"$output"
  [ "$status" -eq 0 ]
  grep -q "Updated Acme" "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md"
  [ "$(jq -r '.skills.acme.ref' "$FIXTURE_ROOT/skills-lock.json")" = "$target_ref" ]

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]

  run python3 "$TOOL" check \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "$target_ref"
  [ "$status" -eq 0 ]
  run jq -e '.status == "success" and .changed == false and .packages == []' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "source-scoped update rejects content changes at the same immutable ref" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  upstream="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$upstream/skills/acme"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" "$upstream/skills/acme/SKILL.md"
  printf '\nchanged without a new commit\n' >>"$upstream/skills/acme/SKILL.md"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "0123456789abcdef0123456789abcdef01234567"
  [ "$status" -ne 0 ]
  [[ "$output" == *"same ref"*"hash mismatch"* ]]
  run grep -q "changed without" "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md"
  [ "$status" -eq 1 ]
}

@test "declared generated artifacts are excluded from hashes and updates" {
  run python3 "$TOOL" hash \
    --package "$FIXTURE_ROOT/.agents/skills/acme" \
    --exclude "Archive.zip"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.skills.acme.excludedPaths = ["Archive.zip"]' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  upstream="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$upstream/skills/acme"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" "$upstream/skills/acme/SKILL.md"
  printf 'opaque generated content\n' >"$upstream/skills/acme/Archive.zip"
  target_ref="1111111111111111111111111111111111111111"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "$target_ref"
  [ "$status" -eq 0 ]
  run jq -e '
    .changed == true and
    .excludedPaths.acme == ["Archive.zip"]
  ' <<<"$output"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_ROOT/.agents/skills/acme/Archive.zip" ]

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "repository lock classifies and verifies every installed skill" {
  run python3 "$TOOL" validate-lock \
    --repo "$REPO_ROOT" \
    --lock "$REPO_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}
