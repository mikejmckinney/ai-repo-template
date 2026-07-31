#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CALLER="$REPO_ROOT/.github/workflows/agent-workflow-pr-smoke.yml"
  REUSABLE="$REPO_ROOT/.github/workflows/agent-workflow-smoke.yml"
  FIXTURE_RUNNER="$REPO_ROOT/scripts/workflows/validate-pr-workflow-fixtures.py"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "PR smoke workflows have only the intended read-only structure" {
  [ -f "$CALLER" ]
  [ -f "$REUSABLE" ]

  run python3 - "$CALLER" "$REUSABLE" <<'PY'
import re
import sys
from pathlib import Path

def mapping_paths(path):
    values = {}
    stack = []
    text = Path(path).read_text(encoding="utf-8")
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#") or raw.lstrip().startswith("-"):
            continue
        match = re.match(r'^(\s*)([^:#][^:]*):(?:\s*(.*))?$', raw)
        if not match:
            continue
        indent = len(match.group(1))
        key = match.group(2).strip().strip('"\'')
        value = (match.group(3) or "").strip()
        while stack and stack[-1][0] >= indent:
            stack.pop()
        current = tuple(item[1] for item in stack) + (key,)
        values[current] = value
        if not value:
            stack.append((indent, key))
    return text, values

caller_text, caller = mapping_paths(sys.argv[1])
reusable_text, reusable = mapping_paths(sys.argv[2])

assert caller[("permissions", "contents")] == "read"
assert caller[("jobs", "smoke", "permissions", "contents")] == "read"
assert {path[1] for path in caller if len(path) == 2 and path[0] == "jobs"} == {"smoke"}
assert caller[("jobs", "smoke", "uses")] == "./.github/workflows/agent-workflow-smoke.yml"
assert caller[("jobs", "smoke", "with", "ref")] == "${{ github.event.pull_request.head.sha }}"
assert caller[("jobs", "smoke", "with", "expected_sha")] == "${{ github.event.pull_request.head.sha }}"
assert set(caller) & {
    ("jobs", "smoke", "runs-on"),
    ("jobs", "smoke", "steps"),
} == set()

assert reusable[("permissions", "contents")] == "read"
assert reusable[("jobs", "smoke", "permissions", "contents")] == "read"
assert {path[1] for path in reusable if len(path) == 2 and path[0] == "jobs"} == {"smoke"}
assert reusable[("jobs", "smoke", "runs-on")] == "ubuntu-latest"
assert reusable[("on", "workflow_call", "inputs", "ref", "required")] == "true"
assert reusable[("on", "workflow_call", "inputs", "expected_sha", "required")] == "true"

allowed_permissions = {
    ("permissions",),
    ("permissions", "contents"),
    ("jobs", "smoke", "permissions"),
    ("jobs", "smoke", "permissions", "contents"),
}
for values in (caller, reusable):
    permission_paths = {path for path in values if "permissions" in path}
    assert permission_paths <= allowed_permissions
for text in (caller_text, reusable_text):
    assert "${{ secrets." not in text
    assert "secrets: inherit" not in text
assert "persist-credentials: false" in reusable_text
assert "git rev-parse HEAD" in reusable_text
PY

  [ "$status" -eq 0 ]
}

@test "fixture paths execute production provenance validators and renderers" {
  run python3 - "$REUSABLE" "$FIXTURE_RUNNER" <<'PY'
import sys
from pathlib import Path

workflow = Path(sys.argv[1]).read_text(encoding="utf-8")
runner = Path(sys.argv[2]).read_text(encoding="utf-8")
assert "validate-postmerge-retro-daily.py" in runner
assert "render-evidence-coverage-meta.py" in runner
assert "build-weekly-review-batch.py" in runner
assert "validate-weekly-review-batch.py" in runner
assert "render-provider-provenance.py" in runner
assert "actions/upload-artifact@v4" in workflow
assert "validate-pr-workflow-fixtures.py" in workflow
assert "scripts/tests/verification-evidence.bats" in workflow
assert "scripts/tests/provider-provenance.bats" in workflow
PY

  [ "$status" -eq 0 ]
}

@test "fixture runner produces bounded daily and weekly artifacts" {
  run python3 "$FIXTURE_RUNNER" --output-dir "$TMP_DIR/artifacts"

  [ "$status" -eq 0 ]
  run jq -e '.pr_evidence_coverage[0].routing_context.provenance.observed_model == "fixture-observed"' \
    "$TMP_DIR/artifacts/daily/daily-retro.json"
  [ "$status" -eq 0 ]
  run jq -e '.provenance.requested_model == "fixture-requested" and (.findings | length) == 0' \
    "$TMP_DIR/artifacts/weekly/weekly-review.json"
  [ "$status" -eq 0 ]
}
