#!/usr/bin/env bats
#
# scripts/tests/pr-resolve-all-poll.bats
#
# Contract tests for scripts/pr-resolve-all-poll.sh (issue #326) plus
# parity checks for the canonical bot allow-list mirrors.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
}

setup() {
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/check-326.XXXXXX")"
  MOCK_BIN="$TMP_DIR/bin"
  mkdir -p "$MOCK_BIN"
  export TMP_DIR MOCK_BIN
}

teardown() {
  rm -rf "$TMP_DIR"
}

iso_timestamp_n_seconds_ago() {
  jq -nr --argjson secs "$1" 'now - $secs | todateiso8601'
}

write_mock_gh() {
  cat >"$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${MOCK_GH_STATE_DIR:?}"
COUNTER_FILE="$STATE_DIR/counter"
if [[ "${1:-}" == "auth" && ( "${2:-}" == "status" || "${2:-}" == "token" ) ]]; then
  expected_host="${MOCK_GH_EXPECT_AUTH_HOST:-}"
  actual_host="github.com"
  if [[ "${3:-}" == "-h" && -n "${4:-}" ]]; then
    actual_host="$4"
  fi
  if [[ -n "$expected_host" && "$actual_host" != "$expected_host" ]]; then
    echo "unexpected gh auth host: expected $expected_host, got $actual_host" >&2
    exit 1
  fi
  exit 0
fi

if [[ "${1:-}" == "repo" && "${2:-}" == "view" ]]; then
  if [[ -n "${MOCK_GH_EXPECT_REPO_HOST:-}" && "${GH_HOST:-}" != "${MOCK_GH_EXPECT_REPO_HOST}" ]]; then
    echo "unexpected GH_HOST for repo view: expected ${MOCK_GH_EXPECT_REPO_HOST}, got ${GH_HOST:-<unset>}" >&2
    exit 1
  fi
  printf '%s\n' "${MOCK_GH_REPO_VIEW:-mikejmckinney/ai-repo-template}"
  exit 0
fi

if [[ "${1:-}" != "api" || "${2:-}" != "graphql" ]]; then
  echo "unexpected gh invocation: $*" >&2
  exit 1
fi

if [[ -n "${MOCK_GH_EXPECT_OWNER:-}" || -n "${MOCK_GH_EXPECT_NAME:-}" ]]; then
  actual_owner=""
  actual_name=""
  api_args=("$@")
  for ((i = 2; i < ${#api_args[@]}; i++)); do
    case "${api_args[$i]}" in
      -F)
        key="${api_args[$((i + 1))]%%=*}"
        value="${api_args[$((i + 1))]#*=}"
        case "$key" in
          owner) actual_owner="$value" ;;
          name) actual_name="$value" ;;
        esac
        i=$((i + 1))
        ;;
      -f)
        i=$((i + 1))
        ;;
    esac
  done
  if [[ -n "${MOCK_GH_EXPECT_OWNER:-}" && "$actual_owner" != "${MOCK_GH_EXPECT_OWNER}" ]]; then
    echo "unexpected GraphQL owner: expected ${MOCK_GH_EXPECT_OWNER}, got ${actual_owner:-<unset>}" >&2
    exit 1
  fi
  if [[ -n "${MOCK_GH_EXPECT_NAME:-}" && "$actual_name" != "${MOCK_GH_EXPECT_NAME}" ]]; then
    echo "unexpected GraphQL name: expected ${MOCK_GH_EXPECT_NAME}, got ${actual_name:-<unset>}" >&2
    exit 1
  fi
fi

count=0
if [[ -f "$COUNTER_FILE" ]]; then
  count=$(cat "$COUNTER_FILE")
fi
count=$((count + 1))
printf '%s\n' "$count" >"$COUNTER_FILE"

if [[ -n "${MOCK_GH_FAIL_AT:-}" && "$count" -eq "$MOCK_GH_FAIL_AT" ]]; then
  echo "mocked gh failure at call $count" >&2
  exit 1
fi

fixture="${STATE_DIR}/${count}.json"
if [[ ! -f "$fixture" ]]; then
  echo "missing fixture for call $count: $fixture" >&2
  exit 1
fi
cat "$fixture"
EOF
  chmod +x "$MOCK_BIN/gh"
}

write_mock_jq() {
  local real_jq
  real_jq="$(command -v jq)"
  cat >"$MOCK_BIN/jq" <<EOF
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="\${MOCK_GH_STATE_DIR:?}"
REAL_JQ="$real_jq"

last_arg="\${!#}"
if [[ "\${MOCK_JQ_FAIL_ALLOWLIST_NORMALIZE:-}" == "1" ]]; then
  for arg in "\$@"; do
    if [[ "\$arg" == *"bot-allowlist-normalize.jq" ]]; then
      echo "mocked jq allowlist normalize failure" >&2
      exit 1
    fi
  done
fi

if [[ "\$last_arg" == *"/post-head.json" ]]; then
  count_file="\$STATE_DIR/jq-post-head-count"
  count=0
  if [[ -f "\$count_file" ]]; then
    count=\$(cat "\$count_file")
  fi
  count=\$((count + 1))
  printf '%s\n' "\$count" >"\$count_file"
  if [[ "\$count" -eq 2 ]]; then
    echo "mocked jq failure for post-head snapshot" >&2
    exit 4
  fi
fi

exec "\$REAL_JQ" "\$@"
EOF
  chmod +x "$MOCK_BIN/jq"
}

write_converged_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-1","commits":{"nodes":[{"commit":{"oid":"sha-1","committedDate":"2026-05-17T16:13:12Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[{"author":{"login":"gemini-code-assist"},"submittedAt":"2026-05-17T16:13:40Z","state":"COMMENTED","commit":{"oid":"sha-1"}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-1","commits":{"nodes":[{"commit":{"oid":"sha-1","committedDate":"2026-05-17T16:13:12Z"}}]}}}}}
EOF
}

write_quiet_elapsed_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-quiet","commits":{"nodes":[{"commit":{"oid":"sha-quiet","committedDate":"2026-05-17T16:00:00Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-quiet","commits":{"nodes":[{"commit":{"oid":"sha-quiet","committedDate":"2026-05-17T16:00:00Z"}}]}}}}}
EOF
}

write_sha_changed_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-old","commits":{"nodes":[{"commit":{"oid":"sha-old","committedDate":"2026-05-17T16:00:00Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-new","commits":{"nodes":[{"commit":{"oid":"sha-new","committedDate":"2026-05-17T16:05:00Z"}}]}}}}}
EOF
}

write_sha_changed_bad_post_head_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-old","commits":{"nodes":[{"commit":{"oid":"sha-old","committedDate":"2026-05-17T16:00:00Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-new","commits":{"nodes":[{"commit":{"oid":"sha-new","committedDate":"2026-05-17T16:05:00Z"}}]}}}}}
EOF
}

write_timeout_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-timeout","commits":{"nodes":[{"commit":{"oid":"sha-timeout","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[{"author":{"login":"gemini-code-assist"},"submittedAt":"2026-05-21T00:00:05Z","state":"COMMENTED","commit":{"oid":"sha-timeout"}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"PRRT_timeout","isResolved":false,"comments":{"nodes":[{"author":{"login":"gemini-code-assist"},"createdAt":"2026-05-21T00:00:06Z"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-timeout","commits":{"nodes":[{"commit":{"oid":"sha-timeout","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
}

write_dismissed_review_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-dismissed","commits":{"nodes":[{"commit":{"oid":"sha-dismissed","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[{"author":{"login":"gemini-code-assist"},"submittedAt":"2026-05-21T00:00:05Z","state":"APPROVED","commit":{"oid":"sha-dismissed"}},{"author":{"login":"gemini-code-assist"},"submittedAt":"2026-05-21T00:00:10Z","state":"DISMISSED","commit":{"oid":"sha-dismissed"}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-dismissed","commits":{"nodes":[{"commit":{"oid":"sha-dismissed","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
}

write_recent_activity_fixtures() {
  local old_head_ts recent_comment_ts
  old_head_ts="$(iso_timestamp_n_seconds_ago 600)"
  recent_comment_ts="$(iso_timestamp_n_seconds_ago 5)"

  cat >"$TMP_DIR/1.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-recent","commits":{"nodes":[{"commit":{"oid":"sha-recent","committedDate":"$old_head_ts"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<EOF
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[{"author":{"login":"mikejmckinney"},"createdAt":"$recent_comment_ts"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-recent","commits":{"nodes":[{"commit":{"oid":"sha-recent","committedDate":"$old_head_ts"}}]}}}}}
EOF
}

write_pending_review_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-pending","commits":{"nodes":[{"commit":{"oid":"sha-pending","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[{"author":{"login":"gemini-code-assist"},"submittedAt":"2026-05-21T00:00:05Z","state":"COMMENTED","commit":{"oid":"sha-pending"}},{"author":{"login":"gemini-code-assist"},"submittedAt":null,"state":"PENDING","commit":null}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-pending","commits":{"nodes":[{"commit":{"oid":"sha-pending","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
}

write_stale_old_head_pending_review_fixtures() {
  local old_head_ts
  old_head_ts="$(iso_timestamp_n_seconds_ago 600)"

  cat >"$TMP_DIR/1.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-current","commits":{"nodes":[{"commit":{"oid":"sha-current","committedDate":"$old_head_ts"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[{"author":{"login":"gemini-code-assist"},"submittedAt":"2026-05-21T00:00:05Z","state":"COMMENTED","commit":{"oid":"sha-current"}},{"author":{"login":"gemini-code-assist"},"submittedAt":null,"state":"PENDING","commit":{"oid":"sha-old"}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-current","commits":{"nodes":[{"commit":{"oid":"sha-current","committedDate":"$old_head_ts"}}]}}}}}
EOF
}

write_invalid_timestamp_fixtures() {
  cat >"$TMP_DIR/1.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-badts","commits":{"nodes":[{"commit":{"oid":"sha-badts","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[{"author":{"login":"gemini-code-assist"},"createdAt":"not-a-timestamp"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-badts","commits":{"nodes":[{"commit":{"oid":"sha-badts","committedDate":"2026-05-21T00:00:00Z"}}]}}}}}
EOF
}

write_stale_old_head_review_fixtures() {
  local old_head_ts stale_review_ts
  old_head_ts="$(iso_timestamp_n_seconds_ago 600)"
  stale_review_ts="$(iso_timestamp_n_seconds_ago 5)"

  cat >"$TMP_DIR/1.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-current","commits":{"nodes":[{"commit":{"oid":"sha-current","committedDate":"$old_head_ts"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<EOF
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[{"author":{"login":"gemini-code-assist"},"submittedAt":"$stale_review_ts","state":"COMMENTED","commit":{"oid":"sha-old"}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-current","commits":{"nodes":[{"commit":{"oid":"sha-current","committedDate":"$old_head_ts"}}]}}}}}
EOF
}

write_backdated_comment_only_fixtures() {
  local old_head_ts recent_bot_comment_ts
  old_head_ts="$(iso_timestamp_n_seconds_ago 600)"
  recent_bot_comment_ts="$(iso_timestamp_n_seconds_ago 5)"

  cat >"$TMP_DIR/1.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-backdated","commits":{"nodes":[{"commit":{"oid":"sha-backdated","committedDate":"$old_head_ts"}}]}}}}}
EOF
  cat >"$TMP_DIR/2.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviews":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/3.json" <<EOF
{"data":{"repository":{"pullRequest":{"comments":{"nodes":[{"author":{"login":"gemini-code-assist"},"createdAt":"$recent_bot_comment_ts"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/4.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
  cat >"$TMP_DIR/5.json" <<EOF
{"data":{"repository":{"pullRequest":{"headRefOid":"sha-backdated","commits":{"nodes":[{"commit":{"oid":"sha-backdated","committedDate":"$old_head_ts"}}]}}}}}
EOF
}

extract_prompt_allowlist() {
  awk '
    /Normalized allow-list/ { in_block = 1; next }
    in_block && /^Worked example:/ { exit }
    in_block && /^- `/ {
      line = $0
      sub(/^- `/, "", line)
      sub(/`.*/, "", line)
      print tolower(line)
    }
  ' "$REPO_ROOT/.github/prompts/pr-resolve-all.md" | sort -u
}

extract_file_allowlist() {
  sed 's/#.*$//' "$REPO_ROOT/scripts/lib/bot-allowlist.txt" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | awk 'NF { print tolower($0) }' \
    | sort -u
}

extract_workflow_allowlist() {
  awk -F'"' '/AI_REVIEWERS="/ { print $2; exit }' "$REPO_ROOT/.github/workflows/agent-relay-reviews.yml" \
    | tr '|' '\n' \
    | awk 'NF { print tolower($0) }' \
    | sort -u
}

extract_fix_workflow_allowlist() {
  awk '
    /Scan ALL review threads/ { in_block = 1 }
    in_block {
      line = $0
      gsub(/.*\(including[[:space:]]*/, "", line)
      gsub(/and any human reviewers\).*/, "", line)
      gsub(/,/, "\n", line)
      print line
      if ($0 ~ /human reviewers\)/) {
        exit
      }
    }
  ' "$REPO_ROOT/.github/workflows/agent-fix-reviews.yml" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | sed '/^$/d' \
    | sed 's/\[bot\]$//' \
    | awk '{ print tolower($0) }' \
    | sort -u
}

extract_docs_allowlist() {
  awk '
    /Keep the doc list and the prompt list/ { in_block = 1; next }
    in_block && /^  Human-authored threads/ { exit }
    in_block && /^  - `/ {
      line = $0
      sub(/^  - `/, "", line)
      sub(/`.*/, "", line)
      print tolower(line)
    }
  ' "$REPO_ROOT/docs/guides/agent-pipeline.md" | sort -u
}

assert_equal_text() {
  local expected="$1" actual="$2" name="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "mismatch: $name" >&2
    echo "expected:" >&2
    printf '%s\n' "$expected" >&2
    echo "actual:" >&2
    printf '%s\n' "$actual" >&2
    false
  fi
}

@test "pr-resolve-all-poll returns RESULT=CONVERGED when participating bots are terminal and no unresolved bot threads remain" {
  write_converged_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=900 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT=CONVERGED HEAD=sha-1"* ]]
}

@test "pr-resolve-all-poll returns RESULT=QUIET_ELAPSED when the quiet window has already elapsed" {
  write_quiet_elapsed_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=10 \
    MAX_WAIT=900 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT=QUIET_ELAPSED HEAD=sha-quiet"* ]]
}

@test "pr-resolve-all-poll does not treat a DISMISSED review as current-head convergence" {
  write_dismissed_review_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=999999999 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT=TIMEOUT HEAD=sha-dismissed"* ]]
}

@test "pr-resolve-all-poll does not treat an older current-head review as terminal when a newer PENDING review exists" {
  write_pending_review_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=999999999 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT=TIMEOUT HEAD=sha-pending"* ]]
}

@test "pr-resolve-all-poll does not return RESULT=QUIET_ELAPSED when a current-head PENDING review exists" {
  write_pending_review_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=0 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT=TIMEOUT HEAD=sha-pending"* ]]
}

@test "pr-resolve-all-poll does not let a stale old-head PENDING review block current-head convergence" {
  write_stale_old_head_pending_review_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=0 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT=CONVERGED HEAD=sha-current"* ]]
}

@test "pr-resolve-all-poll returns RESULT=SHA_CHANGED when the PR head changes mid-snapshot" {
  write_sha_changed_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=900 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 3 ]
  [[ "$output" == *"RESULT=SHA_CHANGED HEAD=sha-new"* ]]
}

@test "pr-resolve-all-poll returns RESULT=API_ERROR when the post-head snapshot cannot be parsed after a head change" {
  write_sha_changed_bad_post_head_fixtures
  write_mock_jq
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=900 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 4 ]
  [[ "$output" == *"RESULT=API_ERROR HEAD=sha-old ERROR=GRAPHQL_HEAD_POST"* ]]
}

@test "pr-resolve-all-poll does not return RESULT=QUIET_ELAPSED when recent PR activity reset the quiet window" {
  write_recent_activity_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT=TIMEOUT HEAD=sha-recent"* ]]
}

@test "pr-resolve-all-poll ignores stale old-head reviews when evaluating the quiet window" {
  write_stale_old_head_review_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT=TIMEOUT HEAD=sha-current"* ]]
}

@test "pr-resolve-all-poll does not return RESULT=CONVERGED for comment-only bot activity on a backdated head" {
  write_backdated_comment_only_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT=TIMEOUT HEAD=sha-backdated"* ]]
}

@test "pr-resolve-all-poll returns RESULT=TIMEOUT when a blocking state persists past MAX_WAIT" {
  write_timeout_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=999999999 \
    MAX_WAIT=0 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT=TIMEOUT HEAD=sha-timeout"* ]]
}

@test "pr-resolve-all-poll returns RESULT=API_ERROR when latest_actionable cannot be parsed as a timestamp" {
  write_invalid_timestamp_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=900 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 4 ]
  [[ "$output" == *"RESULT=API_ERROR HEAD=sha-badts ERROR=TIMESTAMP_PARSE"* ]]
}

@test "pr-resolve-all-poll returns RESULT=API_ERROR when gh is missing under Bash 3.2-safe require_cmd handling" {
  local no_gh_bin
  no_gh_bin="$TMP_DIR/no-gh-bin"
  mkdir -p "$no_gh_bin"
  ln -s "$(command -v bash)" "$no_gh_bin/bash"
  ln -s "$(command -v dirname)" "$no_gh_bin/dirname"
  ln -s "$(command -v tr)" "$no_gh_bin/tr"

  run env \
    PATH="$no_gh_bin" \
    ALLOWLIST_FILE="$REPO_ROOT/scripts/lib/bot-allowlist.txt" \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 4 ]
  [[ "$output" == "RESULT=API_ERROR ERROR=MISSING_GH" ]]
}

@test "pr-resolve-all-poll returns RESULT=API_ERROR when the allow-list file is missing" {
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    ALLOWLIST_FILE="$TMP_DIR/does-not-exist.txt" \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 4 ]
  [[ "$output" == "RESULT=API_ERROR ERROR=MISSING_ALLOWLIST" ]]
}

@test "pr-resolve-all-poll returns a specific API_ERROR subtype when GraphQL snapshotting fails" {
  write_converged_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    MOCK_GH_FAIL_AT=1 \
    GH_REPO="mikejmckinney/ai-repo-template" \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 4 ]
  [[ "$output" == *"RESULT=API_ERROR ERROR=GRAPHQL_HEAD" ]]
}

@test "pr-resolve-all-poll accepts host-qualified GH_REPO inputs and targets auth to that host" {
  write_converged_fixtures
  write_mock_gh
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    MOCK_GH_EXPECT_AUTH_HOST="ghe.example.com" \
    MOCK_GH_EXPECT_OWNER="mikejmckinney" \
    MOCK_GH_EXPECT_NAME="ai-repo-template" \
    GH_REPO="ghe.example.com/mikejmckinney/ai-repo-template" \
    INTERVAL=0 \
    QUIET_WINDOW=360 \
    MAX_WAIT=900 \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT=CONVERGED"* ]]
}

@test "pr-resolve-all-poll returns RESULT=API_ERROR when allow-list jq normalization fails" {
  write_mock_gh
  write_mock_jq
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_GH_STATE_DIR="$TMP_DIR" \
    MOCK_JQ_FAIL_ALLOWLIST_NORMALIZE="1" \
    GH_REPO="mikejmckinney/ai-repo-template" \
    "$REPO_ROOT/scripts/pr-resolve-all-poll.sh" 326
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 4 ]
  [[ "$output" == *"RESULT=API_ERROR ERROR=ALLOWLIST_PARSE_FAIL" ]]
}

@test "canonical bot allow-list stays in sync across prompt workflow and docs mirrors" {
  file_allowlist="$(extract_file_allowlist)"
  prompt_allowlist="$(extract_prompt_allowlist)"
  workflow_allowlist="$(extract_workflow_allowlist)"
  fix_workflow_allowlist="$(extract_fix_workflow_allowlist)"
  docs_allowlist="$(extract_docs_allowlist)"

  assert_equal_text "$file_allowlist" "$prompt_allowlist" "prompt parity"
  assert_equal_text "$file_allowlist" "$workflow_allowlist" "workflow parity"
  assert_equal_text "$file_allowlist" "$fix_workflow_allowlist" "fix workflow parity"
  assert_equal_text "$file_allowlist" "$docs_allowlist" "docs parity"
}
