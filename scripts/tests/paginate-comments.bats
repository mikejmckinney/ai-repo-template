#!/usr/bin/env bats
#
# Paginated gh api comment slurp — multi-page JSON arrays must merge with jq -s add.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-120}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
}

setup() {
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/paginate-comments.XXXXXX")"
  export TMP_DIR
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "jq -s add merges paginated comment pages (upsert lookup pattern)" {
  cat >"$TMP_DIR/page1.json" <<'EOF'
[{"id":1,"body":"<!-- marker:v1 --> first"},{"id":2,"body":"other"}]
EOF
  cat >"$TMP_DIR/page2.json" <<'EOF'
[{"id":3,"body":"<!-- marker:v1 --> latest"}]
EOF

  run bash -c 'cat "$1" "$2" | jq -s '"'"'if length == 0 then [] else add end'"'"' \
    | jq -r --arg marker "<!-- marker:v1 -->" \
      '"'"'[.[] | select((.body | type) == "string" and (.body | contains($marker)))] | last | .id // empty'"'"'' \
    bash "$TMP_DIR/page1.json" "$TMP_DIR/page2.json"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "jq -s add merges paginated arrays; bare jq does not produce one combined array" {
  cat >"$TMP_DIR/page1.json" <<'EOF'
[{"id":1,"body":"first"}]
EOF
  cat >"$TMP_DIR/page2.json" <<'EOF'
[{"id":2,"body":"second"}]
EOF

  run bash -c 'cat "$1" "$2" | jq -s '"'"'if length == 0 then [] else add end'"'"' | jq length' \
    bash "$TMP_DIR/page1.json" "$TMP_DIR/page2.json"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]

  run bash -c 'cat "$1" "$2" | jq length | tail -1' \
    bash "$TMP_DIR/page1.json" "$TMP_DIR/page2.json"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "fetch-daily-retro-json-from-issue slurp sees comments on all pages" {
  cat >"$TMP_DIR/page1.json" <<'EOF'
[{"body":"noise"}]
EOF
  cat >"$TMP_DIR/page2.json" <<'EOF'
[{"body":"<!-- postmerge-retro:daily-json:2026-06-15 run:1 attempt:0 -->\n```json\n{\"run_date\":\"2026-06-15\"}\n```"}]
EOF

  run bash -c 'cat "$1" "$2" | jq -s '"'"'if length == 0 then [] else add end'"'"' | jq length' \
    bash "$TMP_DIR/page1.json" "$TMP_DIR/page2.json"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}
