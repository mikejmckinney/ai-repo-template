#!/usr/bin/env bats
# ADR-026 compliance schema fixture tests.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
}

@test "compliance schema examples parse and validate" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-examples.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"validated"* ]]
}

@test "explicit relative compliance schema example path validates" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-examples.py docs/compliance_schemas.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"validated"* ]]
  [[ "$output" != *"ValueError"* ]]
}

@test "compliance fixtures separate valid and invalid evidence" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-fixtures.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"valid"* ]]
  [[ "$output" == *"invalid"* ]]
}

@test "explicit relative compliance fixture directory validates" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-fixtures.py scripts/tests/fixtures/compliance
  [ "$status" -eq 0 ]
  [[ "$output" == *"validated"* ]]
  [[ "$output" != *"unrecognized arguments"* ]]
}

@test "invalid single compliance fixture fails" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-fixtures.py --single scripts/tests/fixtures/compliance/invalid/overlay-version.yml
  [ "$status" -ne 0 ]
  [[ "$output" == *"overlay_version is not allowed"* ]]
  [[ "$output" != *"ValueError"* ]]
}

@test "compliance markdown extraction tolerates indented fences" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, "scripts/lib")
from compliance_schema import _FRONTMATTER_RE, load_markdown_yaml_blocks

frontmatter = "  ---  \nname: docs\nrole_contract_version: 1\n  ---  \n"
assert _FRONTMATTER_RE.search(frontmatter)

with TemporaryDirectory() as tmp:
    path = Path(tmp) / "example.md"
    path.write_text("  ```yaml  \nsubagent_compliance:\n  schema_version: 1\n  ```  \n", encoding="utf-8")
    blocks = load_markdown_yaml_blocks(path)
    assert len(blocks) == 1
    assert "subagent_compliance" in blocks[0][1]
PY
  [ "$status" -eq 0 ]
}

@test "canonical role versions reject boolean contract versions" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, "scripts/lib")
from compliance_schema import ComplianceError, canonical_role_versions

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    agents = root / ".agents"
    agents.mkdir()
    (agents / "docs.md").write_text(
        "---\nname: docs\nrole_contract_version: true\n---\n",
        encoding="utf-8",
    )
    try:
        canonical_role_versions(root)
    except ComplianceError as exc:
        assert "role_contract_version" in str(exc)
    else:
        raise AssertionError("boolean role_contract_version passed")
PY
  [ "$status" -eq 0 ]
}

@test "repository path validation rejects symlink escapes" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, "scripts/lib")
from compliance_schema import ComplianceError, _validate_repo_path

with TemporaryDirectory() as tmp:
    base = Path(tmp)
    repo = base / "repo"
    outside = base / "outside"
    repo.mkdir()
    outside.mkdir()
    (repo / "link").symlink_to(outside, target_is_directory=True)
    try:
        _validate_repo_path("link/file.md", "fixture.files_modified[0]", repo)
    except ComplianceError as exc:
        assert "must stay within the repository" in str(exc)
    else:
        raise AssertionError("symlink escape passed path validation")
PY
  [ "$status" -eq 0 ]
}

@test "overlay_version README/template exclusion preserves enforced templates" {
  cd "$REPO_ROOT"
  input=$'.agents/README.md:1:overlay_version: 1\n.agents/_TEMPLATE.md:2:overlay_version: 1\n.github/PLAN_TEMPLATE.md:3:overlay_version: 1\n.agents/docs.md:4:overlay_version: 1'
  run bash -c "printf '%s\n' \"$input\" | grep -v '/README\\.md:' | grep -v '/_TEMPLATE\\.md:'"
  [ "$status" -eq 0 ]
  [[ "$output" != *".agents/README.md"* ]]
  [[ "$output" != *".agents/_TEMPLATE.md"* ]]
  [[ "$output" == *".github/PLAN_TEMPLATE.md:3:overlay_version: 1"* ]]
  [[ "$output" == *".agents/docs.md:4:overlay_version: 1"* ]]
}
