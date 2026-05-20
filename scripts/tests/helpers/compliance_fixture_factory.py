"""Compliance fixture factory (CP3 Factory Method / Test Data Builder).

Replaces ~23 hand-rolled invalid-shape YAML fixtures under
``scripts/tests/fixtures/compliance/invalid/`` with programmatic
factories + a registry of (mutation, expected-error-substring) cases.

Design rationale (issue #349, plan v4.7 Δ7):

* Every hand-rolled invalid fixture was a deepcopy of one of the three
  canonical baselines with a single field mutated. Storing 25 near-duplicate
  YAMLs created drift hazard every time the schema changed (Phase C swap
  was the latest example).
* The factory exposes one builder per block type that returns a fresh deep
  copy of the canonical valid baseline. Tests mutate the dict and call
  ``validate_loaded_block``. The registry below enumerates the failure
  cases the deleted fixtures used to cover.
* Cases that are NOT well-suited to programmatic mutation (top-level
  ``schema_version`` routing variants for ``agent-state:v1``, the
  ``agents_md_version`` real-mismatch check that depends on the actual
  AGENTS.md value, and the canonical valid baselines themselves) remain
  on disk under ``fixtures/compliance/{valid,invalid}/``.

The factory deliberately keeps a small, flat surface: dict builders and
a list of named cases. No metaclasses, no decorators, no DSL. Each case
returns a fully-formed block ready to pass to
``compliance_schema.validate_loaded_block``.
"""

from __future__ import annotations

import copy
from typing import Any, Callable

from compliance_schema import current_agents_md_version


def _agents_md_version() -> int:
    """Resolve the live AGENTS.md version for fixture defaults."""

    return current_agents_md_version()


def make_subagent_compliance(**overrides: Any) -> dict[str, Any]:
    """Return a canonical valid ``subagent_compliance`` dict.

    Pass keyword overrides to replace top-level keys. To mutate nested
    keys, call the factory then mutate the returned dict directly.
    """

    version = _agents_md_version()
    block = {
        "subagent_compliance": {
            "role": "docs",
            "role_contract_version": 1,
            "agents_md_version": version,
            "receipt": {
                "mode": "visible-line",
                "value": "Role receipt v1 — docs",
            },
            "context_files_used": [
                "AGENTS.md",
                ".agents/docs.md",
                ".context/rules/process_doc_maintenance.md",
            ],
            "pointers_skipped": [],
            "task_scope": "Factory-built fixture for compliance regression tests.",
            "files_modified": [],
            "gates_invoked": ["doc-trigger-check"],
            "run_status": "SUCCESS",
        }
    }
    block["subagent_compliance"].update(overrides)
    return copy.deepcopy(block)


def make_plan_compliance(**overrides: Any) -> dict[str, Any]:
    """Return a canonical valid ``plan_compliance`` dict."""

    block = {
        "plan_compliance": {
            "applicable_roles": ["architect", "docs"],
            "instruction_resources": [
                {
                    "resource": "AGENTS.md",
                    "why_applicable": "Canonical startup contract.",
                    "evidence": "Session handshake emitted.",
                    "decision_affected": "Required parent evidence in plan.",
                },
                {
                    "resource": ".context/rules/process_subagent_bootstrap.md",
                    "why_applicable": "Work dispatches role subagents.",
                    "evidence": "Dispatch packet fields checked.",
                    "decision_affected": "Planned parsed subagent compliance capture.",
                },
            ],
            "role_dispatch": {
                "decision": "staged-dispatch",
                "planned_subagents": ["architect", "docs"],
                "monolithic_justification": None,
            },
            "plan_gate": {
                "status": "linked",
                "link": "https://github.com/mikejmckinney/ai-repo-template/issues/307",
                "gate_status": {"triggered": True, "applied": True},
            },
            "adr_required": {
                "required": True,
                "link": "docs/decisions/adr-026-compliance-contracts.md",
                "supersession_notes": ["N/A"],
            },
            "doc_sync": {
                "triggered": True,
                "companions": ["AI_REPO_GUIDE.md"],
                "no_change_justifications": [],
            },
            "verification": ["bash test.sh"],
        }
    }
    block["plan_compliance"].update(overrides)
    return copy.deepcopy(block)


def make_parent_compliance(**overrides: Any) -> dict[str, Any]:
    """Return a canonical valid ``parent_compliance`` dict."""

    version = _agents_md_version()
    block = {
        "parent_compliance": {
            "handshake_token": f"Session handshake v{version}",
            "agents_md_version": version,
            "runtime_pointer": {
                "path": ".github/copilot-instructions.md",
                "loaded": True,
                "decision_affected": "Used Copilot-specific dispatch guidance.",
            },
            "applicable_roles": ["docs"],
            "subagents_dispatched": [],
            "monolithic_justification": "Direct docs-only change.",
            "plan_gate": {
                "status": "linked",
                "link": "https://github.com/mikejmckinney/ai-repo-template/issues/307",
                "gate_status": {"triggered": True, "applied": True},
            },
            "diff_gate": {
                "status": "pending",
                "link": None,
                "gate_status": {"triggered": True, "applied": False},
            },
            "adr_required": {"required": False, "link": None},
            "deviations": [],
            "verification_results": [],
        }
    }
    block["parent_compliance"].update(overrides)
    return copy.deepcopy(block)


def make_agent_state(**overrides: Any) -> dict[str, Any]:
    """Return a canonical valid ``agent-state:v1`` block (v1.2 shape)."""

    block: dict[str, Any] = {
        "schema_version": 1.2,
        "opportunity_notes": [],
    }
    block.update(overrides)
    return copy.deepcopy(block)


# ---------------------------------------------------------------------------
# Expected-case registry
# ---------------------------------------------------------------------------
#
# Each case is (name, builder, expected_error_substring). The builder
# returns the FULLY-FORMED dict ready to pass to validate_loaded_block.
# Tests iterate this list, call validate_loaded_block(case_dict), and
# assert that ComplianceError is raised AND its message contains the
# expected substring.
#
# Adding a new failure mode: append one tuple here. Do NOT add a new
# YAML file under fixtures/compliance/invalid/. The dual-folder validator
# remains for the canonical baselines + the cases that genuinely need
# on-disk representation (agent-state routing, AGENTS.md version
# mismatch).


def _case_handshake_mismatch() -> dict[str, Any]:
    return make_parent_compliance(handshake_token="Session handshake v15")


def _case_receipt_mode_invalid() -> dict[str, Any]:
    block = make_subagent_compliance()
    block["subagent_compliance"]["receipt"]["mode"] = "not-a-valid-mode"
    return block


def _case_role_version_bool() -> dict[str, Any]:
    return make_subagent_compliance(role_contract_version=True)


def _case_role_version_mismatch() -> dict[str, Any]:
    return make_subagent_compliance(role_contract_version=99)


def _case_task_scope_empty() -> dict[str, Any]:
    return make_subagent_compliance(task_scope="")


def _case_subagent_list_item_type() -> dict[str, Any]:
    return make_subagent_compliance(context_files_used=[123])


def _case_subagent_files_modified_impossible_path() -> dict[str, Any]:
    return make_subagent_compliance(files_modified=["../escape/from/repo.md"])


def _case_top_level_sibling() -> dict[str, Any]:
    block = make_subagent_compliance()
    block["unexpected_sibling"] = {}
    return block


def _case_overlay_version() -> dict[str, Any]:
    block = make_subagent_compliance()
    block["subagent_compliance"]["overlay_version"] = 1
    return block


def _case_plan_applicable_role_item_type() -> dict[str, Any]:
    return make_plan_compliance(applicable_roles=[123])


def _case_plan_instruction_resource_field_type() -> dict[str, Any]:
    block = make_plan_compliance()
    block["plan_compliance"]["instruction_resources"][0]["resource"] = 42
    return block


def _case_plan_verification_item_type() -> dict[str, Any]:
    return make_plan_compliance(verification=[42])


def _case_parent_applicable_role_empty() -> dict[str, Any]:
    return make_parent_compliance(applicable_roles=[""])


def _case_parent_deviation_item_type() -> dict[str, Any]:
    return make_parent_compliance(deviations=["not-a-dict"])


def _case_parent_verification_result_item_type() -> dict[str, Any]:
    return make_parent_compliance(verification_results=["not-a-dict"])


def _case_parent_plan_gate_missing_fields() -> dict[str, Any]:
    block = make_parent_compliance()
    block["parent_compliance"]["plan_gate"] = {"status": "linked"}
    return block


def _case_runtime_pointer_empty_decision() -> dict[str, Any]:
    block = make_parent_compliance()
    block["parent_compliance"]["runtime_pointer"]["decision_affected"] = ""
    return block


def _case_runtime_pointer_missing_reason() -> dict[str, Any]:
    block = make_parent_compliance()
    block["parent_compliance"]["runtime_pointer"] = {
        "path": None,
        "loaded": False,
        "decision_affected": None,
    }
    return block


def _case_extra_dispatch_role() -> dict[str, Any]:
    block = make_parent_compliance(
        applicable_roles=["docs"],
        subagents_dispatched=[make_subagent_compliance(role="architect")["subagent_compliance"]],
        monolithic_justification="Parent performed remaining docs work directly.",
    )
    return block


def _case_disjoint_dispatch_missing_monolithic() -> dict[str, Any]:
    block = make_parent_compliance(
        applicable_roles=["docs"],
        subagents_dispatched=[make_subagent_compliance(role="architect")["subagent_compliance"]],
        monolithic_justification=None,
    )
    return block


def _case_partial_dispatch_missing_monolithic() -> dict[str, Any]:
    block = make_parent_compliance(
        applicable_roles=["docs", "architect"],
        subagents_dispatched=[make_subagent_compliance(role="docs")["subagent_compliance"]],
        monolithic_justification=None,
    )
    return block


def _case_gate_exemption_reason_rejected() -> dict[str, Any]:
    """Regression: the old `exemption_reason` field (ADR-029 §6) must be rejected.

    Phase C removed `exemption_reason` from `plan_gate` and `diff_gate` in
    favor of `gate_status: {triggered, applied}`. Two prompt files
    (`op-issue-workflow.md`, `instruction-compliance-smoke.md`) still
    referenced the old key after Phase C; Critic caught both in the Phase
    H diff-gate. This case pins the rejection so the validator can't
    silently regrow the escape hatch.

    The fixture includes `gate_status` so `_require_keys` passes (the
    required-keys guard runs before `_reject_unknown_keys`); the extra
    `exemption_reason` key is what we expect the validator to reject.
    """
    block = make_parent_compliance()
    block["parent_compliance"]["plan_gate"] = {
        "status": "linked",
        "link": "https://example.invalid/plan",
        "gate_status": {"triggered": False, "applied": False},
        "exemption_reason": "smoke-test",
    }
    return block


# (name, builder, expected_error_substring)
EXPECTED_INVALID_CASES: list[tuple[str, Callable[[], dict[str, Any]], str]] = [
    ("handshake-mismatch", _case_handshake_mismatch, "handshake_token version does not match"),
    ("receipt-mode-invalid", _case_receipt_mode_invalid, "receipt.mode"),
    ("role-version-bool", _case_role_version_bool, "role_contract_version"),
    ("role-version-mismatch", _case_role_version_mismatch, "role_contract_version"),
    ("task-scope-empty", _case_task_scope_empty, "task_scope"),
    ("subagent-list-item-type", _case_subagent_list_item_type, "context_files_used"),
    ("subagent-files-modified-impossible-path", _case_subagent_files_modified_impossible_path, "files_modified"),
    ("top-level-sibling", _case_top_level_sibling, "unknown top-level"),
    ("overlay-version", _case_overlay_version, "overlay_version"),
    ("plan-applicable-role-item-type", _case_plan_applicable_role_item_type, "applicable_roles"),
    ("plan-instruction-resource-field-type", _case_plan_instruction_resource_field_type, "instruction_resources"),
    ("plan-verification-item-type", _case_plan_verification_item_type, "verification"),
    ("parent-applicable-role-empty", _case_parent_applicable_role_empty, "applicable_roles"),
    ("parent-deviation-item-type", _case_parent_deviation_item_type, "deviations"),
    ("parent-verification-result-item-type", _case_parent_verification_result_item_type, "verification_results"),
    ("parent-plan-gate-missing-fields", _case_parent_plan_gate_missing_fields, "plan_gate"),
    ("runtime-pointer-empty-decision", _case_runtime_pointer_empty_decision, "decision_affected"),
    ("runtime-pointer-missing-reason", _case_runtime_pointer_missing_reason, "reason"),
    ("extra-dispatch-role", _case_extra_dispatch_role, "not declared in applicable_roles"),
    ("disjoint-dispatch-missing-monolithic", _case_disjoint_dispatch_missing_monolithic, "not declared in applicable_roles"),
    ("partial-dispatch-missing-monolithic", _case_partial_dispatch_missing_monolithic, "monolithic_justification"),
    ("gate-exemption-reason-rejected", _case_gate_exemption_reason_rejected, "exemption_reason"),
]
