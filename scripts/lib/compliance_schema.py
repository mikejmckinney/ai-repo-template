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

# Accepted schema_version values for agent-state:v1 routing discriminant.
# v1.2 (additive) adds opportunity_notes; v1 and v1.1 remain accepted.
_ALLOWED_SCHEMA_VERSIONS_V12 = frozenset({1.0, 1.1, 1.2})


def load_yaml(path: Path) -> Any:
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ComplianceError(f"{path}: YAML parse failed: {exc}") from exc


def load_markdown_yaml_blocks(path: Path) -> list[tuple[int, Any]]:
    text = path.read_text(encoding="utf-8")
    # Examples in docs/compliance_schemas.md use the literal placeholder
    # ``<N>`` for the live ``AGENTS_MD_VERSION`` value (ADR-029 §"Canary
    # placeholder convention"). Substitute the live integer before YAML
    # parsing so examples don't go stale on every version bump.
    live_version = current_agents_md_version()
    text = text.replace("Session handshake v<N>", f"Session handshake v{live_version}")
    text = text.replace("agents_md_version: <N>", f"agents_md_version: {live_version}")
    text = text.replace("AGENTS_MD_VERSION <N>", f"AGENTS_MD_VERSION {live_version}")
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
    sources: dict[str, Path] = {}
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
        if role in versions:
            raise ComplianceError(f"{path}: duplicate frontmatter name {role!r}; first declared in {sources[role]}")
        if role != path.stem:
            raise ComplianceError(f"{path}: frontmatter name must match filename stem {path.stem!r}")
        if type(version) is not int or version < 1:
            raise ComplianceError(f"{path}: missing positive integer role_contract_version")
        versions[role] = version
        sources[role] = path
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


def _require_schema_version_v12(mapping: dict[str, Any], source: str) -> None:
    """Accept schema_version values 1, 1.1, and 1.2 (int or float, not bool)."""
    version = mapping.get("schema_version")
    if version is None or type(version) is bool or not isinstance(version, (int, float)):
        type_name = type(version).__name__ if version is not None else "NoneType"
        raise ComplianceError(f"{source}.schema_version: expected int or float, got {type_name}")
    if float(version) not in _ALLOWED_SCHEMA_VERSIONS_V12:
        allowed = ", ".join(str(int(v) if v == int(v) else v) for v in sorted(_ALLOWED_SCHEMA_VERSIONS_V12))
        raise ComplianceError(
            f"{source}: schema_version must be one of {{{allowed}}}; got {version}"
        )


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
    resolved_root = repo_root.resolve()
    current = resolved_root
    for part in path.parts:
        candidate = current / part
        if not candidate.exists() and not candidate.is_symlink():
            break
        resolved_candidate = candidate.resolve(strict=False)
        try:
            resolved_candidate.relative_to(resolved_root)
        except ValueError as exc:
            raise ComplianceError(f"{source}: must stay within the repository") from exc
        current = resolved_candidate


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
    allowed = {"status", "link", "gate_status"}
    _require_keys(block, allowed, source)
    _reject_unknown_keys(block, allowed, source)
    _require_non_empty_string(block["status"], f"{source}.status")
    _require_nullable_string(block["link"], f"{source}.link")
    _validate_gate_status(block["gate_status"], f"{source}.gate_status")


def _validate_gate_status(block: Any, source: str) -> None:
    _require_type(block, dict, source)
    allowed = {"triggered", "applied"}
    _require_keys(block, allowed, source)
    _reject_unknown_keys(block, allowed, source)
    _require_bool(block["triggered"], f"{source}.triggered")
    _require_bool(block["applied"], f"{source}.applied")


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



_OPPORTUNITY_NOTE_REQUIRED_KEYS = frozenset({
    "title", "evidence", "impact", "recommendation", "scope",
    "suggested_next_action", "confidence", "role_relevance", "duplicate_check",
})

# Enum allowed-values from .context/rules/process_opportunity_feedback.md
# § "Required fields (9 total)". suggested_next_action also accepts the
# parameterised form `fold-into-<digits>` (e.g. `fold-into-337`).
_OPPORTUNITY_SCOPE_VALUES = frozenset({"rule", "script", "doc", "workflow", "code", "test", "process"})
_OPPORTUNITY_CONFIDENCE_VALUES = frozenset({"high", "medium", "low"})
_OPPORTUNITY_NEXT_ACTION_LITERALS = frozenset({"file-issue", "discuss", "defer"})
_OPPORTUNITY_FOLD_INTO_RE = re.compile(r"^fold-into-\d+$")
# Canonical role names — derived dynamically from .agents/<role>.md frontmatter
# via canonical_role_versions() rather than hardcoded, so adding/removing a
# canonical role file is automatically reflected here (PR #344 R15 gemini).
# Accepts repo_root so callers that pass a non-default repo (tests, fixtures)
# get role values from that tree, not the module-level REPO_ROOT
# (PR #344 R16 cursor).
def _opportunity_role_values(repo_root: Path = REPO_ROOT) -> frozenset[str]:
    return frozenset(canonical_role_versions(repo_root).keys())
# Title length cap from process_opportunity_feedback.md § "Required fields".
_OPPORTUNITY_TITLE_MAX = 80


def _validate_opportunity_notes(
    items: Any,
    source: str,
    repo_root: Path = REPO_ROOT,
    valid_roles: Optional[frozenset[str]] = None,
) -> None:
    """Validate the optional opportunity_notes list (v1.2, cap <=3 per session).

    ``valid_roles`` may be passed in by callers that have already computed
    the canonical role set (e.g. ``validate_subagent`` reuses ``versions``)
    to avoid re-walking ``.agents/*.md``. Uses an explicit ``is not None``
    check so an empty frozenset injected by tests still suppresses the
    fallback disk walk (PR #344 R18 gemini).
    """
    _require_type(items, list, source)
    if not items:
        return
    if len(items) > 3:
        raise ComplianceError(f"{source}: opportunity_notes must have <=3 entries; got {len(items)}")
    # Compute valid_roles once outside the per-item loop so .agents/*.md is
    # walked once per list, not once per item (PR #344 R17 gemini), unless
    # the caller already supplied the set (PR #344 R18 gemini).
    if valid_roles is None:
        valid_roles = _opportunity_role_values(repo_root)
    for idx, item in enumerate(items):
        item_source = f"{source}[{idx}]"
        _require_type(item, dict, item_source)
        _require_keys(item, _OPPORTUNITY_NOTE_REQUIRED_KEYS, item_source)
        _reject_unknown_keys(item, _OPPORTUNITY_NOTE_REQUIRED_KEYS, item_source)
        _require_non_empty_string(item["title"], f"{item_source}.title")
        if len(item["title"]) > _OPPORTUNITY_TITLE_MAX:
            raise ComplianceError(
                f"{item_source}.title: must be <={_OPPORTUNITY_TITLE_MAX} characters; got {len(item['title'])}"
            )
        _require_non_empty_string(item["evidence"], f"{item_source}.evidence")
        _require_non_empty_string(item["impact"], f"{item_source}.impact")
        _require_non_empty_string(item["recommendation"], f"{item_source}.recommendation")
        _require_non_empty_string(item["scope"], f"{item_source}.scope")
        if item["scope"] not in _OPPORTUNITY_SCOPE_VALUES:
            allowed = ", ".join(sorted(_OPPORTUNITY_SCOPE_VALUES))
            raise ComplianceError(f"{item_source}.scope: must be one of {{{allowed}}}; got {item['scope']!r}")
        _require_non_empty_string(item["suggested_next_action"], f"{item_source}.suggested_next_action")
        nxt = item["suggested_next_action"]
        if nxt not in _OPPORTUNITY_NEXT_ACTION_LITERALS and not _OPPORTUNITY_FOLD_INTO_RE.match(nxt):
            allowed = ", ".join(sorted(_OPPORTUNITY_NEXT_ACTION_LITERALS)) + ", fold-into-<n>"
            raise ComplianceError(f"{item_source}.suggested_next_action: must be one of {{{allowed}}}; got {nxt!r}")
        _require_non_empty_string(item["confidence"], f"{item_source}.confidence")
        if item["confidence"] not in _OPPORTUNITY_CONFIDENCE_VALUES:
            allowed = ", ".join(sorted(_OPPORTUNITY_CONFIDENCE_VALUES))
            raise ComplianceError(f"{item_source}.confidence: must be one of {{{allowed}}}; got {item['confidence']!r}")
        _require_string_list(item["role_relevance"], f"{item_source}.role_relevance")
        for role in item["role_relevance"]:
            if role not in valid_roles:
                allowed = ", ".join(sorted(valid_roles))
                raise ComplianceError(
                    f"{item_source}.role_relevance: contains invalid role {role!r}; must be one of {{{allowed}}}"
                )
        _require_non_empty_string(item["duplicate_check"], f"{item_source}.duplicate_check")


def validate_plan(block: dict[str, Any], source: str) -> None:
    allowed_keys = {
        "applicable_roles",
        "instruction_resources",
        "role_dispatch",
        "plan_gate",
        "adr_required",
        "doc_sync",
        "verification",
    }
    _require_keys(block, allowed_keys, source)
    _reject_unknown_keys(block, allowed_keys, source)
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
    allowed_keys = {
        "role",
        "role_contract_version",
        "agents_md_version",
        "receipt",
        "context_files_used",
        "pointers_skipped",
        "task_scope",
        "files_modified",
        "gates_invoked",
        # v1.1 (additive, optional): see docs/compliance_schemas.md.
        # run_status MUST remain optional at v1 to preserve backward compat
        # with v1.0 producers per the versioning policy. The silent-failure
        # escape hatch raised by codex (PR #312 R7) is addressed at the Judge
        # diff-gate (.agents/judge.md item 19), not at the schema layer.
        "run_status",
        "apply_replays",
        # v1.2 (additive, optional): opportunity feedback channel.
        "opportunity_notes",
    }
    required_keys = allowed_keys - {"run_status", "apply_replays", "opportunity_notes"}
    _require_keys(block, required_keys, source)
    _reject_unknown_keys(block, allowed_keys, source)
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
    receipt_keys = {"mode", "value"}
    _require_keys(block["receipt"], receipt_keys, f"{source}.receipt")
    _reject_unknown_keys(block["receipt"], receipt_keys, f"{source}.receipt")
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

    # v1.1 optional: run_status (enum) + apply_replays (list of byte-anchored
    # patches). See docs/compliance_schemas.md § 'subagent_compliance v1'.
    # Kept optional at v1 to preserve backward compat per versioning policy.
    run_status = block.get("run_status")
    if run_status is not None:
        _require_non_empty_string(run_status, f"{source}.run_status")
        allowed_statuses = {"SUCCESS", "PARTIAL", "BLOCKED_ON_RUNTIME", "NEEDS_CONTEXT"}
        if run_status not in allowed_statuses:
            raise ComplianceError(
                f"{source}.run_status: must be one of {sorted(allowed_statuses)}; got {run_status!r}"
            )
    apply_replays = block.get("apply_replays")
    if apply_replays is not None:
        _require_type(apply_replays, list, f"{source}.apply_replays")
        for idx, item in enumerate(apply_replays):
            item_source = f"{source}.apply_replays[{idx}]"
            _require_type(item, dict, item_source)
            replay_keys = {"path", "anchor", "replacement"}
            _require_keys(item, replay_keys, item_source)
            _reject_unknown_keys(item, replay_keys, item_source)
            _require_non_empty_string(item["path"], f"{item_source}.path")
            # Replays apply patches; the path must be repo-relative just like
            # files_modified — otherwise an attacker-controlled subagent
            # response could declare apply_replays[].path = '../../etc/passwd'
            # or 'http://evil/.../passwd' and pass schema validation while
            # describing a write outside the repo (PR #312 codex P2).
            _validate_repo_path(item["path"], f"{item_source}.path", repo_root)
            _require_non_empty_string(item["anchor"], f"{item_source}.anchor")
            _require_type(item["replacement"], str, f"{item_source}.replacement")
    # NOTE: a non-SUCCESS run_status with empty apply_replays is permitted at
    # the schema layer. The verify-or-replay contract documented in
    # `.context/rules/process_subagent_bootstrap.md` § "Parent handling of
    # pass-back evidence" treats this case as a process compliance failure
    # the parent must document in `monolithic_justification` (and the judge
    # diff-gates per `.agents/judge.md` item 19). Enforcing it here would
    # make that documented "without-replay" path unsatisfiable.

    # v1.2 optional: opportunity_notes (cap <=3 entries per session per agent).
    # Reuse the already-computed ``versions`` map so opportunity_notes
    # validation doesn't re-walk .agents/*.md (PR #344 R18 gemini).
    opportunity_notes = block.get("opportunity_notes")
    if opportunity_notes is not None:
        _validate_opportunity_notes(
            opportunity_notes,
            f"{source}.opportunity_notes",
            repo_root,
            valid_roles=frozenset(versions.keys()),
        )


def validate_state(block: dict[str, Any], source: str, repo_root: Path = REPO_ROOT) -> None:
    """Validate the structured YAML block embedded in an agent-state:v1 comment.

    Accepts ``schema_version`` values 1, 1.1, and 1.2 when called directly
    (e.g. via a ``subagent_compliance.state`` sub-block).  Note that the
    top-level ``validate_loaded_block`` heuristic only routes bare
    ``agent-state:v1`` YAML to this function when ``schema_version`` is
    numerically exactly 1.2 (the version that introduced
    ``opportunity_notes``); bare blocks tagged ``1`` or ``1.1`` keep their
    pre-PR-#344 behavior and fall through to ``unknown top-level keys``.
    ``opportunity_notes`` is optional (v1.2).  All other agent-state
    fields are free-form prose outside this structured block and are not
    validated here.
    """
    allowed_keys = {
        "schema_version",
        # v1.2 (additive, optional): opportunity feedback channel.
        "opportunity_notes",
    }
    _require_keys(block, {"schema_version"}, source)
    _reject_unknown_keys(block, allowed_keys, source)
    _require_schema_version_v12(block, source)
    opportunity_notes = block.get("opportunity_notes")
    if opportunity_notes is not None:
        _validate_opportunity_notes(opportunity_notes, f"{source}.opportunity_notes", repo_root)


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
    allowed_keys = {
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
    }
    _require_keys(block, allowed_keys, source)
    _reject_unknown_keys(block, allowed_keys, source)
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
    # Agent-state:v1 YAML blocks are embedded in GitHub comments without a
    # compliance-key wrapper (plan_compliance / parent_compliance /
    # subagent_compliance). Detect by:
    #   1. The block contains schema_version (required for state).
    #   2. schema_version is numerically exactly 1.2 — the additive v1.2
    #      revision is the only agent-state schema validate_state enforces
    #      here. Older bare blocks (e.g. {schema_version: 1}) keep their
    #      pre-PR-#344 behavior and fall through to "unknown top-level
    #      keys", preventing a stray YAML fragment from silently passing.
    #   3. The block's key set is a subset of _AGENT_STATE_KEYS, i.e. it
    #      contains ONLY schema_version and optionally opportunity_notes.
    # If a future state field is added, extend _AGENT_STATE_KEYS (and the
    # version check) in lockstep with docs/compliance_schemas.md
    # § "agent-state:v1".
    _AGENT_STATE_KEYS = {"schema_version", "opportunity_notes"}
    schema_version = data.get("schema_version")
    is_v12_numeric = (
        isinstance(schema_version, (int, float))
        and not isinstance(schema_version, bool)
        and float(schema_version) == 1.2
    )
    if is_v12_numeric and set(data.keys()).issubset(_AGENT_STATE_KEYS):
        validate_state(data, source, repo_root)
        return
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
