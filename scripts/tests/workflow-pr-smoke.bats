#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CALLER="$REPO_ROOT/.github/workflows/agent-workflow-pr-smoke.yml"
  REUSABLE="$REPO_ROOT/.github/workflows/agent-workflow-smoke.yml"
}

@test "PR smoke caller invokes same-commit reusable workflow" {
  [ -f "$CALLER" ]
  [ -f "$REUSABLE" ]

  run python3 - "$CALLER" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert "pull_request:" in text
assert "uses: ./.github/workflows/agent-workflow-smoke.yml" in text
assert "github.event.pull_request.head.sha" in text
assert "secrets: inherit" not in text
PY

  [ "$status" -eq 0 ]
}

@test "reusable PR smoke workflow is read-only and verifies candidate SHA" {
  run python3 - "$REUSABLE" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert "workflow_call:" in text
assert "contents: read" in text
assert "persist-credentials: false" in text
assert "git rev-parse HEAD" in text
assert "expected_sha" in text
assert "verification-evidence.bats" in text
assert "provider-provenance.bats" in text
assert "secrets:" not in text
assert "issues: write" not in text
assert "pull-requests: write" not in text
PY

  [ "$status" -eq 0 ]
}
