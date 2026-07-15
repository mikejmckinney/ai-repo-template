#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/format-links-test.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "Markdown link checker accepts valid relative and repo-root links" {
  mkdir -p "$TEST_ROOT/docs"
  printf '# Target\n' >"$TEST_ROOT/docs/target.md"
  printf '[relative](target.md) [root](/docs/target.md) [web](https://example.com)\n' >"$TEST_ROOT/docs/source.md"

  run python3 "$REPO_ROOT/scripts/check-markdown-links.py" \
    --repo-root "$TEST_ROOT" "$TEST_ROOT/docs/source.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"checked 1 Markdown file"* ]]
}

@test "Markdown link checker reports the source and missing target" {
  mkdir -p "$TEST_ROOT/docs"
  printf '[missing](gone.md)\n' >"$TEST_ROOT/docs/source.md"

  run python3 "$REPO_ROOT/scripts/check-markdown-links.py" \
    --repo-root "$TEST_ROOT" "$TEST_ROOT/docs/source.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/source.md:1"* ]]
  [[ "$output" == *"gone.md"* ]]
}

@test "local formatter check and write modes dispatch by file type" {
  mkdir -p "$TEST_ROOT/bin"
  printf '#!/usr/bin/env bash\nprintf "shfmt:%%s\\n" "$*" >>"$FORMAT_LOG"\n' >"$TEST_ROOT/bin/shfmt"
  printf '#!/usr/bin/env bash\nprintf "npx:%%s\\n" "$*" >>"$FORMAT_LOG"\n' >"$TEST_ROOT/bin/npx"
  chmod +x "$TEST_ROOT/bin/shfmt" "$TEST_ROOT/bin/npx"
  printf 'echo test\n' >"$TEST_ROOT/test.sh"
  printf '# Test\n' >"$TEST_ROOT/test.md"
  export FORMAT_LOG="$TEST_ROOT/format.log"

  run env PATH="$TEST_ROOT/bin:$PATH" "$REPO_ROOT/scripts/format.sh" \
    --check "$TEST_ROOT/test.sh" "$TEST_ROOT/test.md"
  [ "$status" -eq 0 ]
  grep -q 'shfmt:-d' "$FORMAT_LOG"
  grep -q 'markdownlint-cli2@0.17.2' "$FORMAT_LOG"

  : >"$FORMAT_LOG"
  run env PATH="$TEST_ROOT/bin:$PATH" "$REPO_ROOT/scripts/format.sh" \
    --write "$TEST_ROOT/test.sh" "$TEST_ROOT/test.md"
  [ "$status" -eq 0 ]
  grep -q 'shfmt:-w' "$FORMAT_LOG"
  grep -q -- '--fix' "$FORMAT_LOG"
}
