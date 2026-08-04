#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

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
      sourceMetadata: {
        "example/acme-skills": {
          license: "MIT",
          evidence: [{label: "LICENSE", path: "skills/acme/SKILL.md"}]
        }
      },
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

@test "license inventory is rendered from canonical source metadata and refs" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  mkdir -p "$FIXTURE_ROOT/docs/guides"
  cat >"$FIXTURE_ROOT/docs/guides/skill-supply-chain.md" <<'EOF'
# Fixture

<!-- generated:skill-license-inventory:begin -->
stale
<!-- generated:skill-license-inventory:end -->
EOF

  run python3 "$TOOL" render-license-inventory \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"

  [ "$status" -eq 0 ]
  grep -Fq '| `example/acme-skills` | 1 | MIT | [LICENSE](https://github.com/example/acme-skills/blob/0123456789abcdef0123456789abcdef01234567/skills/acme/SKILL.md) |' \
    "$FIXTURE_ROOT/docs/guides/skill-supply-chain.md"
}

@test "license inventory rejects missing or malformed metadata without mutation" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  mkdir -p "$FIXTURE_ROOT/docs/guides"
  cat >"$FIXTURE_ROOT/docs/guides/skill-supply-chain.md" <<'EOF'
# Fixture

<!-- generated:skill-license-inventory:begin -->
stale
<!-- generated:skill-license-inventory:end -->
EOF
  guide_before="$(sha256sum "$FIXTURE_ROOT/docs/guides/skill-supply-chain.md")"

  jq 'del(.sourceMetadata["example/acme-skills"])' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"
  run python3 "$TOOL" render-license-inventory \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sourceMetadata is missing sources"* ]]
  [ "$(sha256sum "$FIXTURE_ROOT/docs/guides/skill-supply-chain.md")" = "$guide_before" ]

  write_lock "$(python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme")"
  jq '.sourceMetadata["example/acme-skills"].evidence[0].path = "../LICENSE"' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"
  run python3 "$TOOL" render-license-inventory \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"path contains path traversal"* ]]
  [ "$(sha256sum "$FIXTURE_ROOT/docs/guides/skill-supply-chain.md")" = "$guide_before" ]
}

@test "source refresh rejects unavailable license evidence without mutation" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.sourceMetadata["example/acme-skills"].evidence[0] = {label: "LICENSE", path: "LICENSE"}' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  upstream="$BATS_TEST_TMPDIR/upstream-missing-license"
  mkdir -p "$upstream/skills/acme"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" "$upstream/skills/acme/SKILL.md"
  printf '\nupdated package\n' >>"$upstream/skills/acme/SKILL.md"
  lock_before="$(sha256sum "$FIXTURE_ROOT/skills-lock.json")"
  skill_before="$(sha256sum "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md")"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"

  [ "$status" -ne 0 ]
  [[ "$output" == *"license evidence is missing"*"example/acme-skills/LICENSE"* ]]
  [ "$(sha256sum "$FIXTURE_ROOT/skills-lock.json")" = "$lock_before" ]
  [ "$(sha256sum "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md")" = "$skill_before" ]
}

@test "source refresh rejects a missing Markdown license fragment" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.sourceMetadata["example/acme-skills"].evidence[0] = {
    label: "License section", path: "README.md", fragment: "license"
  }' "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  upstream="$BATS_TEST_TMPDIR/upstream-missing-fragment"
  mkdir -p "$upstream/skills/acme"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" "$upstream/skills/acme/SKILL.md"
  printf '\nupdated package\n' >>"$upstream/skills/acme/SKILL.md"
  printf '# Project\n\n## Terms\n' >"$upstream/README.md"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"

  [ "$status" -ne 0 ]
  [[ "$output" == *"license evidence fragment is missing"*"README.md#license"* ]]
}

@test "source refresh accepts GitHub fragments from linked and repeated headings" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.sourceMetadata["example/acme-skills"].evidence = [
    {label: "License", path: "README.md", fragment: "license"},
    {label: "Repeated license", path: "README.md", fragment: "license-1"}
  ]' "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  upstream="$BATS_TEST_TMPDIR/upstream-linked-fragments"
  mkdir -p "$upstream/skills/acme"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" "$upstream/skills/acme/SKILL.md"
  printf '\nupdated package\n' >>"$upstream/skills/acme/SKILL.md"
  printf '# Project\n\n## [License](LICENSE)\n\n## License\n' >"$upstream/README.md"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"

  [ "$status" -eq 0 ]
}

@test "aggregate refresh report preserves prior and current source changes" {
  base_lock="$BATS_TEST_TMPDIR/base-lock.json"
  current_lock="$BATS_TEST_TMPDIR/current-lock.json"
  report="$BATS_TEST_TMPDIR/aggregate-report.jsonl"
  jq -n '{skills: {
    alpha: {source: "example/alpha", ref: "1111111111111111111111111111111111111111", computedHash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
    beta: {source: "example/beta", ref: "2222222222222222222222222222222222222222", computedHash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}
  }}' >"$base_lock"
  jq '.skills.alpha.ref = "3333333333333333333333333333333333333333"
    | .skills.alpha.computedHash = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    | .skills.beta.ref = "4444444444444444444444444444444444444444"
    | .skills.beta.computedHash = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"' \
    "$base_lock" >"$current_lock"

  run python3 "$TOOL" render-refresh-report \
    --base-lock "$base_lock" \
    --current-lock "$current_lock"

  [ "$status" -eq 0 ]
  printf '%s\n' "$output" >"$report"
  [ "$(jq -s 'length' "$report")" -eq 2 ]
  [ "$(jq -s -r 'map(.source) | join(",")' "$report")" = "example/alpha,example/beta" ]
  [ "$(jq -s -r '.[0].hashes.alpha.new' "$report")" = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" ]
  [ "$(jq -s -r '.[1].hashes.beta.old' "$report")" = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ]
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

@test "bundle records declare and update nested skill entrypoints" {
  mkdir -p "$FIXTURE_ROOT/.agents/skills/acme/nested"
  cat >"$FIXTURE_ROOT/.agents/skills/acme/nested/SKILL.md" <<'EOF'
---
name: acme-nested
description: Nested fixture skill.
---

# Nested Acme
EOF

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.skills.acme.skillEntrypoints = ["SKILL.md", "nested/SKILL.md"]' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]

  upstream="$BATS_TEST_TMPDIR/upstream-bundle"
  mkdir -p "$upstream/skills/acme/nested"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" "$upstream/skills/acme/SKILL.md"
  cat >"$upstream/skills/acme/nested/SKILL.md" <<'EOF'
---
name: acme-nested
description: Updated nested fixture skill.
---

# Updated Nested Acme
EOF

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"
  [ "$status" -eq 0 ]
  grep -q "Updated Nested Acme" "$FIXTURE_ROOT/.agents/skills/acme/nested/SKILL.md"
}

@test "bundle entrypoints must be sorted safe SKILL.md paths" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.skills.acme.skillEntrypoints = ["nested/SKILL.md", "SKILL.md"]' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"skillEntrypoints"*"sorted"* ]]
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

@test "source-scoped check suppresses ref-only refreshes" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  upstream="$BATS_TEST_TMPDIR/upstream-ref-only"
  mkdir -p "$upstream/skills"
  cp -R "$FIXTURE_ROOT/.agents/skills/acme" "$upstream/skills/acme"

  run python3 "$TOOL" check \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"

  [ "$status" -eq 0 ]
  run jq -e \
    '.changed == false and .refChanged == true and .packages == []' <<<"$output"
  [ "$status" -eq 0 ]
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

@test "material source refresh advances unchanged sibling package refs atomically" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  mkdir -p "$FIXTURE_ROOT/.agents/skills/beta"
  cat >"$FIXTURE_ROOT/.agents/skills/beta/SKILL.md" <<'EOF'
---
name: beta
description: Unchanged sibling fixture.
---

# Beta
EOF
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/beta"
  [ "$status" -eq 0 ]
  beta_hash="$output"
  jq --arg hash "$beta_hash" '.skills.beta = (
    .skills.acme
    | .skillPath = "skills/beta"
    | .destinationPath = ".agents/skills/beta"
    | .computedHash = $hash
  )' "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  upstream="$BATS_TEST_TMPDIR/upstream-siblings"
  mkdir -p "$upstream/skills"
  cp -R "$FIXTURE_ROOT/.agents/skills/acme" "$upstream/skills/acme"
  cp -R "$FIXTURE_ROOT/.agents/skills/beta" "$upstream/skills/beta"
  printf '\nmaterial update\n' >>"$upstream/skills/acme/SKILL.md"
  target_ref="1111111111111111111111111111111111111111"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "$target_ref"

  [ "$status" -eq 0 ]
  run jq -e --arg ref "$target_ref" \
    '.changed == true and .packages == ["acme"] and
     .refOnlyPackages == ["beta"] and .deletedPackages == [] and
     .newRef == $ref' <<<"$output"
  [ "$status" -eq 0 ]
  run jq -e --arg ref "$target_ref" \
    '.skills.acme.ref == $ref and .skills.beta.ref == $ref' \
    "$FIXTURE_ROOT/skills-lock.json"
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

@test "excluded generated-only changes do not trigger refreshes" {
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
    .changed == false and
    .refChanged == true and
    .excludedPaths.acme == ["Archive.zip"]
  ' <<<"$output"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_ROOT/.agents/skills/acme/Archive.zip" ]

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "local overrides validate but block source refresh until removed" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  upstream_hash="$output"
  write_lock "$upstream_hash"

  printf '\nlocal correctness fix\n' >>"$FIXTURE_ROOT/.agents/skills/acme/SKILL.md"
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  local_hash="$output"
  jq --arg local_hash "$local_hash" --arg upstream_hash "$upstream_hash" '
    .skills.acme.computedHash = $local_hash |
    .skills.acme.localOverride = {
      issue: "https://github.com/example/repo/issues/1",
      reason: "Temporary local correctness fix pending upstream support.",
      upstreamHash: $upstream_hash,
      paths: ["SKILL.md"]
    }
  ' "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]

  upstream="$BATS_TEST_TMPDIR/upstream-local-override"
  mkdir -p "$upstream/skills/acme"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" "$upstream/skills/acme/SKILL.md"
  run python3 "$TOOL" check \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"

  [ "$status" -ne 0 ]
  [[ "$output" == *"source has local overrides"*"acme"* ]]
}

@test "local override metadata fails closed when incomplete" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"
  jq '.skills.acme.localOverride = {reason: "missing evidence"}' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"localOverride"* ]]
}

@test "repository lock classifies and verifies every installed skill" {
  run python3 "$TOOL" validate-lock \
    --repo "$REPO_ROOT" \
    --lock "$REPO_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "single-file skill packages update without importing sibling content" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output" "skills/acme/SKILL.md"
  jq '.skills.acme.packageType = "file"' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"

  upstream="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$upstream/skills/acme" "$upstream/skills/unrelated"
  cat >"$upstream/skills/acme/SKILL.md" <<'EOF'
---
name: acme
description: Updated single-file skill.
---

# Updated Acme
EOF
  printf 'must not be imported\n' >"$upstream/skills/unrelated/content.txt"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"
  [ "$status" -eq 0 ]
  grep -q "Updated Acme" "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md"
  [ "$(find "$FIXTURE_ROOT/.agents/skills/acme" -type f | wc -l)" -eq 1 ]

  run python3 "$TOOL" validate-lock \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "missing upstream package fails closed without deleting vendored content" {
  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  upstream="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$upstream/skills"

  run python3 "$TOOL" check \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"
  [ "$status" -ne 0 ]
  [[ "$output" == *"upstream skill path is missing"*"refusing deletion"* ]]

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "1111111111111111111111111111111111111111"
  [ "$status" -ne 0 ]
  [ -e "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" ]
  run jq -e '.skills | has("acme")' "$FIXTURE_ROOT/skills-lock.json"
  [ "$status" -eq 0 ]
}

@test "moved package recovery lets update advance changed bytes and ref atomically" {
  run grep -q 'Update only `skillPath`' \
    "$REPO_ROOT/docs/guides/skill-supply-chain.md"
  [ "$status" -eq 0 ]

  run python3 "$TOOL" hash --package "$FIXTURE_ROOT/.agents/skills/acme"
  [ "$status" -eq 0 ]
  write_lock "$output"

  upstream="$BATS_TEST_TMPDIR/upstream-moved"
  mkdir -p "$upstream/packages/acme"
  cp "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md" \
    "$upstream/packages/acme/SKILL.md"
  printf '\nmoved package update\n' >>"$upstream/packages/acme/SKILL.md"

  jq '.skills.acme.skillPath = "packages/acme" | .sourceMetadata["example/acme-skills"].evidence[0].path = "packages/acme/SKILL.md"' \
    "$FIXTURE_ROOT/skills-lock.json" >"$FIXTURE_ROOT/skills-lock.next"
  mv "$FIXTURE_ROOT/skills-lock.next" "$FIXTURE_ROOT/skills-lock.json"
  target_ref="1111111111111111111111111111111111111111"

  run python3 "$TOOL" update \
    --repo "$FIXTURE_ROOT" \
    --lock "$FIXTURE_ROOT/skills-lock.json" \
    --source "example/acme-skills" \
    --source-dir "$upstream" \
    --ref "$target_ref"
  [ "$status" -eq 0 ]
  run jq -e --arg ref "$target_ref" \
    '.changed == true and .packages == ["acme"] and .newRef == $ref' \
    <<<"$output"
  [ "$status" -eq 0 ]
  grep -q "moved package update" "$FIXTURE_ROOT/.agents/skills/acme/SKILL.md"
  [ "$(jq -r '.skills.acme.ref' "$FIXTURE_ROOT/skills-lock.json")" = "$target_ref" ]
}
