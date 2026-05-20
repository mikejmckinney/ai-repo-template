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
  run python3 scripts/validate-compliance-fixtures.py --single scripts/tests/fixtures/compliance/invalid/agents-version-stale.yml
  [ "$status" -ne 0 ]
  [[ "$output" == *"agents_md_version"* ]]
  [[ "$output" != *"ValueError"* ]]
}

@test "compliance fixture factory registry covers deleted YAML cases" {
  cd "$REPO_ROOT"
  run env PYTHONPATH="scripts/lib:scripts/tests" python3 - <<'PY'
from helpers.compliance_fixture_factory import EXPECTED_INVALID_CASES
from compliance_schema import ComplianceError, validate_loaded_block

failures = []
for name, builder, expected in EXPECTED_INVALID_CASES:
    try:
        validate_loaded_block(builder(), source=f"factory:{name}")
    except ComplianceError as exc:
        msg = str(exc)
        if expected not in msg:
            failures.append(f"{name}: expected substring {expected!r} not in {msg!r}")
        continue
    failures.append(f"{name}: expected ComplianceError but block validated")

if failures:
    for line in failures:
        print(line)
    raise SystemExit(1)
print(f"factory registry: {len(EXPECTED_INVALID_CASES)} cases verified")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"cases verified"* ]]
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

@test "canonical role versions require names to match filenames" {
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
    (agents / "backend.md").write_text(
        "---\nname: docs\nrole_contract_version: 1\n---\n",
        encoding="utf-8",
    )
    try:
        canonical_role_versions(root)
    except ComplianceError as exc:
        assert "frontmatter name must match filename stem" in str(exc)
    else:
        raise AssertionError("mismatched canonical role name passed")
PY
  [ "$status" -eq 0 ]
}

@test "canonical role versions reject duplicate role names" {
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
        "---\nname: docs\nrole_contract_version: 1\n---\n",
        encoding="utf-8",
    )
    (agents / "zz-duplicate.md").write_text(
        "---\nname: docs\nrole_contract_version: 2\n---\n",
        encoding="utf-8",
    )
    try:
        canonical_role_versions(root)
    except ComplianceError as exc:
        assert "duplicate frontmatter name" in str(exc)
    else:
        raise AssertionError("duplicate canonical role name passed")
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
    (repo / "dangling").symlink_to(base / "missing-outside", target_is_directory=True)
    try:
        _validate_repo_path("dangling/file.md", "fixture.files_modified[0]", repo)
    except ComplianceError as exc:
        assert "must stay within the repository" in str(exc)
    else:
        raise AssertionError("dangling symlink escape passed path validation")
PY
  [ "$status" -eq 0 ]
}

@test "parent compliance rejects unknown nested keys" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import copy
import sys
import yaml
from pathlib import Path

sys.path.insert(0, "scripts/lib")
from compliance_schema import ComplianceError, validate_loaded_block

data = yaml.safe_load(Path("scripts/tests/fixtures/compliance/valid/parent-compliance.yml").read_text())
data = copy.deepcopy(data)
data["parent_compliance"]["extra"] = "not allowed"
try:
    validate_loaded_block(data, source="fixture")
except ComplianceError as exc:
    assert "unknown keys: extra" in str(exc)
else:
    raise AssertionError("unknown parent_compliance key passed")
PY
  [ "$status" -eq 0 ]
}

@test "plan compliance rejects unknown nested keys" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import copy
import sys
import yaml
from pathlib import Path

sys.path.insert(0, "scripts/lib")
from compliance_schema import ComplianceError, validate_loaded_block

data = yaml.safe_load(Path("scripts/tests/fixtures/compliance/valid/plan-compliance.yml").read_text())
data = copy.deepcopy(data)
data["plan_compliance"]["verificaiton"] = ["typo"]
try:
    validate_loaded_block(data, source="fixture")
except ComplianceError as exc:
    assert "unknown keys: verificaiton" in str(exc)
else:
    raise AssertionError("unknown plan_compliance key passed")
PY
  [ "$status" -eq 0 ]
}

@test "subagent compliance rejects unknown nested keys" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import copy
import sys
import yaml
from pathlib import Path

sys.path.insert(0, "scripts/lib")
from compliance_schema import ComplianceError, validate_loaded_block

data = yaml.safe_load(Path("scripts/tests/fixtures/compliance/valid/subagent-compliance.yml").read_text())
data = copy.deepcopy(data)
data["subagent_compliance"]["extra"] = "not allowed"
try:
    validate_loaded_block(data, source="fixture")
except ComplianceError as exc:
    assert "unknown keys: extra" in str(exc)
else:
    raise AssertionError("unknown subagent_compliance key passed")
PY
  [ "$status" -eq 0 ]
}

@test "subagent compliance rejects unknown receipt keys" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import copy
import sys
import yaml
from pathlib import Path

sys.path.insert(0, "scripts/lib")
from compliance_schema import ComplianceError, validate_loaded_block

data = yaml.safe_load(Path("scripts/tests/fixtures/compliance/valid/subagent-compliance.yml").read_text())
data = copy.deepcopy(data)
data["subagent_compliance"]["receipt"]["extra"] = "not allowed"
try:
    validate_loaded_block(data, source="fixture")
except ComplianceError as exc:
    assert "fixture.subagent_compliance.receipt: unknown keys: extra" in str(exc)
else:
    raise AssertionError("unknown subagent_compliance receipt key passed")
PY
  [ "$status" -eq 0 ]
}

@test "overlay_version README/template exclusion preserves enforced templates" {
  cd "$REPO_ROOT"
  input=$'.agents/README.md:1:overlay_version: 1\n.agents/_TEMPLATE.md:2:overlay_version: 1\n.github/PLAN_TEMPLATE.md:3:overlay_version: 1\n.agents/docs.md:4:overlay_version: 1\n.agents/qa.md:5:not_overlay_version: 1\n.agents/pm.md:6:overlay_version_extra: 1'
  run bash -c "printf '%s\n' \"$input\" | grep -v '/README\\.md:' | grep -v '/_TEMPLATE\\.md:'"
  [ "$status" -eq 0 ]
  [[ "$output" != *".agents/README.md"* ]]
  [[ "$output" != *".agents/_TEMPLATE.md"* ]]
  [[ "$output" == *".github/PLAN_TEMPLATE.md:3:overlay_version: 1"* ]]
  [[ "$output" == *".agents/docs.md:4:overlay_version: 1"* ]]
}

@test "overlay_version grep pattern ignores adjacent names" {
  cd "$REPO_ROOT"
  run bash -c "printf '%s\n' 'not_overlay_version: 1' 'overlay_version_extra: 1' 'overlay_version: 1' 'overlay_version : 1' | grep -E '\\boverlay_version\\b[[:space:]]*:'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"overlay_version: 1"* ]]
  [[ "$output" == *"overlay_version : 1"* ]]
  [[ "$output" != *"not_overlay_version"* ]]
  [[ "$output" != *"overlay_version_extra"* ]]
}
