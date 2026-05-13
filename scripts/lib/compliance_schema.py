#!/usr/bin/env python3
"""Small validators for ADR-026 compliance evidence blocks.

These validators intentionally check declared evidence shape and version
consistency only. They do not claim to prove what an agent runtime read,
dispatched, or executed.
"""

from __future__ import annotations

import re
from pathlib import Path, PurePosixPath
from typing import Any, Dict, Optional, Tuple, Union

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


_FRONTMATTER_RE = re.compile(r"\A[ \t]*---[ \t]*\n(.*?)\n[ \t]*---[ \t]*(?:\n|$)", re.DOTALL)
_YAML_FENCE_RE = re.compile(r"^[ \t]*```yaml[ \t]*\n(.*?)\n[ \t]*```[ \t]*(?:\n|$)", re.DOTALL | re.MULTILINE)
_AGENTS_MD_VERSION_RE = re.compile(r"AGENTS_MD_VERSION:\s*(?P<version>\d+)")
_HANDSHAKE_RE = re.compile(r"^Session handshake v(?P<version>\d+)$")


def load_yaml(path: Path) -> Any:
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ComplianceError(f"{path}: YAML parse failed: {exc}") from exc


def load_markdown_yaml_blocks(path: Path) -> list[tuple[int, Any]]:
    text = path.read_text(encoding="utf-8")
    blocks: list[tuple[int, Any]] = []
    current_line = 1
    current_offset = 0
    for match in _YAML_FENCE_RE.finditer(text):
        current_line += text.count("\n", current_offset, match.start())
        current_offset = match.start()
        try:
            parsed = yaml.safe_load(match.group(1))
        except yaml.YAMLError as exc:
            raise ComplianceError(f"{path}:{current_line}: YAML parse failed: {exc}") from exc
        if parsed is not None:
            blocks.append((current_line, parsed))
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
        if type(version) is not int or version < 1:
            raise ComplianceError(f"{path}: missing positive integer role_contract_version")
        versions[role] = version
    return versions


def current_agents_md_version(repo_root: Path = REPO_ROOT) -> int:
    path = repo_root / "AGENTS.md"
    match = _AGENTS_MD_VERSION_RE.search(path.read_text(encoding="utf-8"))
    if not match:
        raise ComplianceError(f"{path}: missing AGENTS_MD_VERSION marker")
    return int(match.group("version"))


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


def _reject_unknown_keys(mapping: dict[str, Any], allowed: set[str], source: str) -> None:
    unknown_keys = [key for key in mapping if key not in allowed]
    if unknown_keys:
        formatted = ", ".join(str(key) for key in unknown_keys)
        raise ComplianceError(f"{source}: unknown keys: {formatted}")


def _require_type(value: Any, expected_type: Union[type, Tuple[type, ...]], source: str) -> None:
    if isinstance(expected_type, tuple):
        matches = any(_matches_expected_type(value, item) for item in expected_type)
    else:
        matches = _matches_expected_type(value, expected_type)
    if not matches:
        if isinstance(expected_type, tuple):
            expected = " or ".join(t.__name__ for t in expected_type)
        else:
            expected = expected_type.__name__
        raise ComplianceError(f"{source}: expected {expected}, got {type(value).__name__}")


def _matches_expected_type(value: Any, expected_type: type) -> bool:
    if expected_type is int:
        return type(value) is int
    return isinstance(value, expected_type)


def _require_non_empty_string(value: Any, source: str) -> None:
    _require_type(value, str, source)
    if not value.strip():
        raise ComplianceError(f"{source}: must be a non-empty string")


def _require_nullable_string(value: Any, source: str) -> None:
    if value is None:
        return
    _require_non_empty_string(value, source)


def _require_bool(value: Any, source: str) -> None:
    _require_type(value, bool, source)


def _require_schema_version(mapping: dict[str, Any], source: str) -> None:
    _require_type(mapping.get("schema_version"), int, f"{source}.schema_version")
    if mapping["schema_version"] != 1:
        raise ComplianceError(f"{source}: schema_version must be 1")


def _require_string_list(items: Any, source: str) -> None:
    _require_type(items, list, source)
    for idx, item in enumerate(items):
        _require_non_empty_string(item, f"{source}[{idx}]")


def _validate_repo_path_list(items: Any, source: str, repo_root: Path) -> None:
    _require_type(items, list, source)
    for idx, item in enumerate(items):
        _validate_repo_path(item, f"{source}[{idx}]", repo_root)


def _validate_repo_path(value: Any, source: str, repo_root: Path) -> None:
    _require_non_empty_string(value, source)
    if "://" in value or value.startswith(("/", "~")):
        raise ComplianceError(f"{source}: must be a repository-relative path")
    path = PurePosixPath(value)
    if not path.parts or any(part in {"", ".", ".."} for part in path.parts):
        raise ComplianceError(f"{source}: must not contain empty, current-directory, or parent-directory segments")
    if any(part.startswith("<") and part.endswith(">") for part in path.parts):
        raise ComplianceError(f"{source}: must not contain placeholder path segments")
    resolved = (repo_root / Path(*path.parts)).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise ComplianceError(f"{source}: must stay within the repository") from exc


def _validate_pointers_skipped(items: Any, source: str) -> None:
    _require_type(items, list, source)
    for idx, item in enumerate(items):
        item_source = f"{source}[{idx}]"
        _require_type(item, dict, item_source)
        _require_keys(item, {"path", "reason"}, item_source)
        unknown_keys = [key for key in item if key not in {"path", "reason"}]
        if unknown_keys:
            formatted = ", ".join(str(key) for key in unknown_keys)
            raise ComplianceError(f"{item_source}: unknown keys: {formatted}")
        _require_non_empty_string(item["path"], f"{item_source}.path")
        _require_non_empty_string(item["reason"], f"{item_source}.reason")


def _validate_instruction_resources(items: Any, source: str) -> None:
    _require_type(items, list, source)
    allowed = {"resource", "why_applicable", "evidence", "decision_affected"}
    for idx, item in enumerate(items):
        item_source = f"{source}[{idx}]"
        _require_type(item, dict, item_source)
        _require_keys(item, allowed, item_source)
        _reject_unknown_keys(item, allowed, item_source)
        for key in allowed:
            _require_non_empty_string(item[key], f"{item_source}.{key}")


def _validate_role_dispatch(block: Any, source: str) -> None:
    _require_type(block, dict, source)
    allowed = {"decision", "planned_subagents", "monolithic_justification"}
    _require_keys(block, allowed, source)
    _reject_unknown_keys(block, allowed, source)
    _require_non_empty_string(block["decision"], f"{source}.decision")
    _require_string_list(block["planned_subagents"], f"{source}.planned_subagents")
    _require_nullable_string(block["monolithic_justification"], f"{source}.monolithic_justification")


def _validate_gate(block: Any, source: str) -> None:
    _require_type(block, dict, source)
    allowed = {"status", "link", "exemption_reason"}
    _require_keys(block, allowed, source)
    _reject_unknown_keys(block, allowed, source)
    _require_non_empty_string(block["status"], f"{source}.status")
    _require_nullable_string(block["link"], f"{source}.link")
    _require_nullable_string(block["exemption_reason"], f"{source}.exemption_reason")


def _validate_adr_required(block: Any, source: str, require_supersession_notes: bool = False) -> None:
    _require_type(block, dict, source)
    allowed = {"required", "link"}
    if require_supersession_notes:
        allowed.add("supersession_notes")
    _require_keys(block, allowed, source)
    _reject_unknown_keys(block, allowed, source)
    _require_bool(block["required"], f"{source}.required")
    _require_nullable_string(block["link"], f"{source}.link")
    if require_supersession_notes:
        _require_string_list(block["supersession_notes"], f"{source}.supersession_notes")


def _validate_doc_sync(block: Any, source: str) -> None:
    _require_type(block, dict, source)
    allowed = {"triggered", "companions", "no_change_justifications"}
    _require_keys(block, allowed, source)
    _reject_unknown_keys(block, allowed, source)
    _require_bool(block["triggered"], f"{source}.triggered")
    _require_string_list(block["companions"], f"{source}.companions")
    _require_string_list(block["no_change_justifications"], f"{source}.no_change_justifications")


def _validate_deviations(items: Any, source: str) -> None:
    _require_type(items, list, source)
    allowed = {"planned", "actual", "reason"}
    for idx, item in enumerate(items):
        item_source = f"{source}[{idx}]"
        _require_type(item, dict, item_source)
        _require_keys(item, allowed, item_source)
        _reject_unknown_keys(item, allowed, item_source)
        for key in allowed:
            _require_non_empty_string(item[key], f"{item_source}.{key}")


def _validate_verification_results(items: Any, source: str) -> None:
    _require_type(items, list, source)
    allowed = {"command", "result", "evidence"}
    for idx, item in enumerate(items):
        item_source = f"{source}[{idx}]"
        _require_type(item, dict, item_source)
        _require_keys(item, allowed, item_source)
        _reject_unknown_keys(item, allowed, item_source)
        for key in allowed:
            _require_non_empty_string(item[key], f"{item_source}.{key}")


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
    _require_string_list(block["applicable_roles"], f"{source}.applicable_roles")
    _validate_instruction_resources(block["instruction_resources"], f"{source}.instruction_resources")
    _validate_role_dispatch(block["role_dispatch"], f"{source}.role_dispatch")
    _validate_gate(block["plan_gate"], f"{source}.plan_gate")
    _validate_adr_required(block["adr_required"], f"{source}.adr_required", require_supersession_notes=True)
    _validate_doc_sync(block["doc_sync"], f"{source}.doc_sync")
    _require_string_list(block["verification"], f"{source}.verification")


def validate_subagent(
    block: dict[str, Any],
    source: str,
    repo_root: Path = REPO_ROOT,
    role_versions: Optional[Dict[str, int]] = None,
    expected_agents_md_version: Optional[int] = None,
) -> None:
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
    current_agents_version = (
        expected_agents_md_version if expected_agents_md_version is not None else current_agents_md_version(repo_root)
    )
    if block["agents_md_version"] != current_agents_version:
        raise ComplianceError(
            f"{source}: agents_md_version {block['agents_md_version']} "
            f"does not match AGENTS.md version {current_agents_version}"
        )
    _require_type(block["receipt"], dict, f"{source}.receipt")
    _require_keys(block["receipt"], {"mode", "value"}, f"{source}.receipt")
    mode = block["receipt"]["mode"]
    _require_non_empty_string(mode, f"{source}.receipt.mode")
    if mode not in {"visible-line", "trailing-block"}:
        raise ComplianceError(f"{source}.receipt.mode: must be 'visible-line' or 'trailing-block'")
    _require_non_empty_string(block["receipt"]["value"], f"{source}.receipt.value")
    _require_string_list(block["context_files_used"], f"{source}.context_files_used")
    _validate_pointers_skipped(block["pointers_skipped"], f"{source}.pointers_skipped")
    _validate_repo_path_list(block["files_modified"], f"{source}.files_modified", repo_root)
    _require_string_list(block["gates_invoked"], f"{source}.gates_invoked")
    _require_non_empty_string(block["task_scope"], f"{source}.task_scope")

    versions = role_versions if role_versions is not None else canonical_role_versions(repo_root)
    role = block["role"]
    if role not in versions:
        raise ComplianceError(f"{source}: role {role!r} has no canonical .agents/<role>.md file")
    if block["role_contract_version"] != versions[role]:
        raise ComplianceError(
            f"{source}: role_contract_version {block['role_contract_version']} "
            f"does not match .agents/{role}.md version {versions[role]}"
        )


def validate_runtime_pointer(block: dict[str, Any], source: str) -> None:
    _require_keys(block, {"path", "loaded", "decision_affected"}, source)
    unknown_keys = [key for key in block if key not in {"path", "loaded", "decision_affected", "reason"}]
    if unknown_keys:
        formatted = ", ".join(str(key) for key in unknown_keys)
        raise ComplianceError(f"{source}: unknown keys: {formatted}")

    path = block["path"]
    loaded = block["loaded"]
    decision_affected = block["decision_affected"]
    _require_type(loaded, bool, f"{source}.loaded")
    _require_nullable_string(decision_affected, f"{source}.decision_affected")

    if path is None:
        if loaded is not False:
            raise ComplianceError(f"{source}: loaded must be false when path is null")
        if "reason" not in block:
            raise ComplianceError(f"{source}: reason is required when path is null")
        _require_type(block["reason"], str, f"{source}.reason")
        if not block["reason"].strip():
            raise ComplianceError(f"{source}: reason must be non-empty when path is null")
        return

    _require_type(path, str, f"{source}.path")
    if not path.strip():
        raise ComplianceError(f"{source}: path must be non-empty when present")
    if loaded is not True:
        raise ComplianceError(f"{source}: loaded must be true when path is not null")
    if "reason" in block:
        raise ComplianceError(f"{source}: reason must be omitted when path is not null")


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
    current_agents_version = current_agents_md_version(repo_root)
    if block["agents_md_version"] != current_agents_version:
        raise ComplianceError(
            f"{source}: agents_md_version {block['agents_md_version']} "
            f"does not match AGENTS.md version {current_agents_version}"
        )
    _require_type(block["runtime_pointer"], dict, f"{source}.runtime_pointer")
    validate_runtime_pointer(block["runtime_pointer"], f"{source}.runtime_pointer")
    _require_type(block["applicable_roles"], list, f"{source}.applicable_roles")
    _require_type(block["subagents_dispatched"], list, f"{source}.subagents_dispatched")
    applicable_roles = set()
    for idx, role in enumerate(block["applicable_roles"]):
        _require_non_empty_string(role, f"{source}.applicable_roles[{idx}]")
        applicable_roles.add(role)
    justification = block.get("monolithic_justification")
    if justification is not None:
        _require_type(justification, str, f"{source}.monolithic_justification")
        if not justification.strip():
            raise ComplianceError(f"{source}: monolithic_justification must be non-empty when provided")
    dispatched_roles = set()
    role_versions = canonical_role_versions(repo_root) if block["subagents_dispatched"] else {}
    for idx, subagent in enumerate(block["subagents_dispatched"]):
        _require_type(subagent, dict, f"{source}.subagents_dispatched[{idx}]")
        validate_subagent(
            subagent,
            f"{source}.subagents_dispatched[{idx}]",
            repo_root,
            role_versions=role_versions,
            expected_agents_md_version=current_agents_version,
        )
        dispatched_roles.add(subagent["role"])
    extra_roles = dispatched_roles - applicable_roles
    if extra_roles:
        extra = ", ".join(sorted(extra_roles))
        raise ComplianceError(f"{source}: dispatched roles not declared in applicable_roles: {extra}")
    if not block["subagents_dispatched"] and not justification:
        raise ComplianceError(f"{source}: monolithic_justification required when no subagents are dispatched")
    missing_roles = applicable_roles - dispatched_roles
    if missing_roles and not justification:
        missing = ", ".join(sorted(missing_roles))
        raise ComplianceError(
            f"{source}: monolithic_justification required when applicable roles were not dispatched: {missing}"
        )
    _validate_gate(block["plan_gate"], f"{source}.plan_gate")
    _validate_gate(block["diff_gate"], f"{source}.diff_gate")
    _validate_adr_required(block["adr_required"], f"{source}.adr_required")
    _validate_deviations(block["deviations"], f"{source}.deviations")
    _validate_verification_results(block["verification_results"], f"{source}.verification_results")


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
