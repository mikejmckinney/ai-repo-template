#!/usr/bin/env bats
# Benchmark execution helpers (#447).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  cd "$REPO_ROOT"
}

@test "split-monolithic-retro-json.py writes per-PR retro files" {
  tmp="$(mktemp -d)"
  cat >"$tmp/llm.txt" <<'EOF'
```json
{
  "prs": [10, 11],
  "retros": [
    {
      "pr": 10,
      "summary": "one",
      "follow_up_issues": []
    },
    {
      "pr": 11,
      "summary": "two",
      "follow_up_issues": []
    }
  ]
}
```
EOF
  run python3 scripts/workflows/postmerge-retro/split-monolithic-retro-json.py \
    "$tmp/llm.txt" "$tmp/out" 10 11
  [ "$status" -eq 0 ]
  [ -f "$tmp/out/pr-10-retro.json" ]
  [ -f "$tmp/out/pr-11-retro.json" ]
  run jq -e '.pr == 10' "$tmp/out/pr-10-retro.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "split-monolithic-retro-json.py fails when expected PR missing" {
  tmp="$(mktemp -d)"
  cat >"$tmp/llm.txt" <<'EOF'
{"prs":[10],"retros":[{"pr":10,"summary":"x","follow_up_issues":[]}]}
EOF
  run python3 scripts/workflows/postmerge-retro/split-monolithic-retro-json.py \
    "$tmp/llm.txt" "$tmp/out" 10 11
  [ "$status" -eq 1 ]
  rm -rf "$tmp"
}
