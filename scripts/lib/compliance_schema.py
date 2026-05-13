#!/usr/bin/env python3
"""Small validators for ADR-026 compliance evidence blocks.

These validators intentionally check declared evidence shape and version
consistency only. They do not claim to prove what an agent runtime read,
dispatched, or executed.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - exercised by environment setup
    raise SystemExit("PyYAML is required for compliance schema validation") from exc


class ComplianceError(ValueError):
    """Raised when a compliance evidence block is malformed."""


REPO_ROOT = Path(__file__).resolve().parents[2]
VALID_TOP_LEVEL_KEYS = {
    "plan_compliance",
    "parent_compliance",
    "subagent_compliance",
}


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
_YAML_FENCE_RE = re.compile(r"```yaml\n(.*?)\n```", re.DOTALL)
_HANDSHAKE_RE = re.compile(r"^Session handshake v(?P<version>\d+)$")


def load_yaml(path: Path) -> Any:
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ComplianceError(f"{path}: YAML parse failed: {exc}") from exc


def load_markdown_yaml_blocks(path: Path) -> list[tuple[int, Any]]:
    text = path.read_text(encoding="utf-8")
    blocks: list[tuple[int, Any]] = []
    for match in _YAML_FENCE_RE.finditer(text):
        line = text[: match.start()].count("\n") + 1
        try:
            parsed = yaml.safe_load(match.group(1))
        except yaml.YAMLError as exc:
            raise ComplianceError(f"{path}:{line}: YAML parse failed: {exc}") from exc
        if parsed is not None:
            blocks.append((line, parsed))
    return blocks


def canonical_role_versions(repo_root: Path = REPO_ROOT) -> dict[str, int]:
    versions: dict[str, int] = {}
    for path in sorted((repo_root / ".agents").glob("*.md")):
        if path.name in {"README.md", "_TEMPLATE.md"}:
            continue
        text = path.read_text(encoding="utf-8")
        match = _FRONTMATTER_RE.search(text)
        if not match:
            raise ComplianceError(f"{path}: missing YAML frontmatter")
        frontmatter = yaml.safe_load(match.group(1)) or {}
        role = frontmatter.get("name")
        version = frontmatter.get("role_contract_version")
        if not isinstance(role, str) or not role:
            raise ComplianceError(f"{path}: missing frontmatter name")
        if not isinstance(version, int) or version < 1:
            raise ComplianceError(f"{path}: missing positive integer role_contract_version")
        versions[role] = version
    return versions


def assert_no_overlay_version(value: Any, source: str) -> None:
    if isinstance(value, dict):
        if "overlay_version" in value:
            raise ComplianceError(f"{source}: overlay_version is not allowed in ADR-026 v1 blocks")
        for child in value.values():
            assert_no_overlay_version(child, source)
    elif isinstance(value, list):
        for child in value:
            assert_no_overlay_version(child, source)


def _require_keys(mapping: dict[str, Any], required: set[str], source: str) -> None:
    missing = sorted(required - set(mapping))
    if missing:
        raise ComplianceError(f"{source}: missing required keys: {', '.join(missing)}")


def _require_type(value: Any, expected_type: type | tuple[type, ...], source: str) -> None:
    if not isinstance(value, expected_type):
        if isinstance(expected_type, tuple):
            expected = " or ".join(t.__name__ for t in expected_type)
        else:
            expected = expected_type.__name__
        raise ComplianceError(f"{source}: expected {expected}, got {type(value).__name__}")


def _require_schema_version(mapping: dict[str, Any], source: str) -> None:
    if mapping.get("schema_version") != 1:
        raise ComplianceError(f"{source}: schema_version must be 1")


def validate_plan(block: dict[str, Any], source: str) -> None:
    _require_keys(
        block,
        {
            "schema_version",
            "applicable_roles",
            "instruction_resources",
            "role_dispatch",
            "plan_gate",
            "adr_required",
            "doc_sync",
            "verification",
        },
        source,
    )
    _require_schema_version(block, source)
    _require_type(block["applicable_roles"], list, f"{source}.applicable_roles")
    _require_type(block["instruction_resources"], list, f"{source}.instruction_resources")
    for idx, item in enumerate(block["instruction_resources"]):
        _require_type(item, dict, f"{source}.instruction_resources[{idx}]")
        _require_keys(
            item,
            {"resource", "why_applicable", "evidence", "decision_affected"},
            f"{source}.instruction_resources[{idx}]",
        )
    _require_type(block["role_dispatch"], dict, f"{source}.role_dispatch")
    _require_keys(
        block["role_dispatch"],
        {"decision", "planned_subagents", "monolithic_justification"},
        f"{source}.role_dispatch",
    )
    _require_type(block["role_dispatch"].get("planned_subagents"), list, f"{source}.role_dispatch.planned_subagents")
    for key in ("plan_gate", "adr_required", "doc_sync"):
        _require_type(block[key], dict, f"{source}.{key}")
    _require_type(block["verification"], list, f"{source}.verification")


def validate_subagent(block: dict[str, Any], source: str, repo_root: Path = REPO_ROOT) -> None:
    _require_keys(
        block,
        {
            "schema_version",
            "role",
            "role_contract_version",
            "agents_md_version",
            "receipt",
            "context_files_used",
            "pointers_skipped",
            "task_scope",
            "files_modified",
            "gates_invoked",
        },
        source,
    )
    _require_schema_version(block, source)
    _require_type(block["role"], str, f"{source}.role")
    _require_type(block["role_contract_version"], int, f"{source}.role_contract_version")
    _require_type(block["agents_md_version"], int, f"{source}.agents_md_version")
    _require_type(block["receipt"], dict, f"{source}.receipt")
    _require_keys(block["receipt"], {"mode", "value"}, f"{source}.receipt")
    for key in ("context_files_used", "pointers_skipped", "files_modified", "gates_invoked"):
        _require_type(block[key], list, f"{source}.{key}")
    _require_type(block["task_scope"], str, f"{source}.task_scope")

    versions = canonical_role_versions(repo_root)
    role = block["role"]
    if role not in versions:
        raise ComplianceError(f"{source}: role {role!r} has no canonical .agents/<role>.md file")
    if block["role_contract_version"] != versions[role]:
        raise ComplianceError(
            f"{source}: role_contract_version {block['role_contract_version']} "
            f"does not match .agents/{role}.md version {versions[role]}"
        )


def validate_parent(block: dict[str, Any], source: str, repo_root: Path = REPO_ROOT) -> None:
    _require_keys(
        block,
        {
            "schema_version",
            "handshake_token",
            "agents_md_version",
            "runtime_pointer",
            "applicable_roles",
            "subagents_dispatched",
            "monolithic_justification",
            "plan_gate",
            "diff_gate",
            "adr_required",
            "deviations",
            "verification_results",
        },
        source,
    )
    _require_schema_version(block, source)
    _require_type(block["handshake_token"], str, f"{source}.handshake_token")
    _require_type(block["agents_md_version"], int, f"{source}.agents_md_version")
    match = _HANDSHAKE_RE.match(block["handshake_token"])
    if not match:
        raise ComplianceError(f"{source}: handshake_token must match 'Session handshake v<N>'")
    if int(match.group("version")) != block["agents_md_version"]:
        raise ComplianceError(f"{source}: handshake_token version does not match agents_md_version")
    _require_type(block["runtime_pointer"], dict, f"{source}.runtime_pointer")
    _require_type(block["applicable_roles"], list, f"{source}.applicable_roles")
    _require_type(block["subagents_dispatched"], list, f"{source}.subagents_dispatched")
    applicable_roles = set()
    for idx, role in enumerate(block["applicable_roles"]):
        _require_type(role, str, f"{source}.applicable_roles[{idx}]")
        applicable_roles.add(role)
    justification = block.get("monolithic_justification")
    if justification is not None:
        _require_type(justification, str, f"{source}.monolithic_justification")
        if not justification.strip():
            raise ComplianceError(f"{source}: monolithic_justification must be non-empty when provided")
    dispatched_roles = set()
    for idx, subagent in enumerate(block["subagents_dispatched"]):
        _require_type(subagent, dict, f"{source}.subagents_dispatched[{idx}]")
        validate_subagent(subagent, f"{source}.subagents_dispatched[{idx}]", repo_root)
        dispatched_roles.add(subagent["role"])
    if not block["subagents_dispatched"] and not justification:
        raise ComplianceError(f"{source}: monolithic_justification required when no subagents are dispatched")
    if applicable_roles and dispatched_roles < applicable_roles and not justification:
        missing_roles = ", ".join(sorted(applicable_roles - dispatched_roles))
        raise ComplianceError(
            f"{source}: monolithic_justification required when dispatched roles are a strict subset "
            f"of applicable_roles (missing: {missing_roles})"
        )
    for key in ("plan_gate", "diff_gate", "adr_required"):
        _require_type(block[key], dict, f"{source}.{key}")
    for key in ("deviations", "verification_results"):
        _require_type(block[key], list, f"{source}.{key}")


def validate_loaded_block(data: Any, source: str, repo_root: Path = REPO_ROOT) -> None:
    _require_type(data, dict, source)
    assert_no_overlay_version(data, source)
    unknown_keys = [key for key in data if key not in VALID_TOP_LEVEL_KEYS]
    if unknown_keys:
        formatted = ", ".join(str(key) for key in unknown_keys)
        raise ComplianceError(f"{source}: unknown top-level keys: {formatted}")
    keys = [key for key in VALID_TOP_LEVEL_KEYS if key in data]
    if len(keys) != 1:
        raise ComplianceError(
            f"{source}: expected exactly one top-level compliance key "
            f"({', '.join(sorted(VALID_TOP_LEVEL_KEYS))})"
        )
    key = keys[0]
    value = data[key]
    _require_type(value, dict, f"{source}.{key}")
    if key == "plan_compliance":
        validate_plan(value, f"{source}.plan_compliance")
    elif key == "parent_compliance":
        validate_parent(value, f"{source}.parent_compliance", repo_root)
    elif key == "subagent_compliance":
        validate_subagent(value, f"{source}.subagent_compliance", repo_root)
