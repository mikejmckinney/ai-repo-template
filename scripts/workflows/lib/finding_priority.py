"""Canonical finding triage validation and priority derivation."""
from __future__ import annotations

from typing import Any

IMPACTS = frozenset({"incorrect-behavior", "dx-perf-doc", "meta-harness"})
TRIGGERS = frozenset({"common", "edge", "fringe"})
FIX_COSTS = frozenset({"trivial", "moderate", "large"})
BANDS = frozenset({"fix-now", "should-fix", "defer"})
IMPACT_MAGNITUDES = frozenset({"bounded", "material", "critical"})
AFFECTED_SCOPES = frozenset({"isolated", "limited", "broad"})
REVERSIBILITIES = frozenset({"easy", "moderate", "hard"})
CONFIDENCES = frozenset({"low", "medium", "high"})
SURFACES = frozenset({"advisory", "formal", "interactive", "postmerge", "weekly"})
TRIAGE_VERSION = 2

FINDING_ARRAYS = ("follow_up_issues",)


def derive_priority_band(
    impact: str,
    trigger_likelihood: str,
    fix_cost: str,
    *,
    regression_guard: bool = False,
) -> str:
    if impact == "incorrect-behavior" and trigger_likelihood == "common":
        return "fix-now"
    if (impact == "incorrect-behavior" and trigger_likelihood == "edge") or (
        fix_cost == "trivial"
        and regression_guard
        and trigger_likelihood != "fringe"
    ):
        return "should-fix"
    return "defer"


def derive_priority_band_v2(
    impact: str,
    impact_magnitude: str,
    trigger_likelihood: str,
    affected_scope: str,
    reversibility: str,
    fix_cost: str,
    confidence: str,
    *,
    regression_guard: bool = False,
) -> str:
    if confidence != "low" and impact == "incorrect-behavior":
        if (
            impact_magnitude in {"material", "critical"}
            and trigger_likelihood == "common"
            and affected_scope == "broad"
            and reversibility == "hard"
        ) or (
            impact_magnitude == "critical"
            and trigger_likelihood in {"common", "edge"}
            and reversibility == "hard"
        ):
            return "fix-now"

    if impact == "incorrect-behavior":
        if impact_magnitude == "critical" and trigger_likelihood != "fringe":
            return "should-fix"
        if impact_magnitude == "material" and trigger_likelihood in {"common", "edge"}:
            return "should-fix"
        if (
            impact_magnitude == "bounded"
            and trigger_likelihood == "common"
            and fix_cost != "large"
        ):
            return "should-fix"

    if fix_cost == "trivial" and regression_guard and trigger_likelihood != "fringe":
        return "should-fix"
    return "defer"


def derive_surface_action(priority_band: str, surface: str) -> str:
    if priority_band not in BANDS:
        raise ValueError(f"priority_band must be one of: {', '.join(sorted(BANDS))}")
    if surface not in SURFACES:
        raise ValueError(f"surface must be one of: {', '.join(sorted(SURFACES))}")
    if surface == "advisory":
        return "optional-input"
    if surface in {"formal", "interactive"}:
        return {
            "fix-now": "request-changes",
            "should-fix": "recommend-fix",
            "defer": "no-action",
        }[priority_band]
    return {
        "fix-now": "open-fix",
        "should-fix": "track-fix",
        "defer": "record-only",
    }[priority_band]


def _parse_regression_guard(item: dict, path: str) -> bool:
    if "regression_guard" not in item:
        return False
    value = item.get("regression_guard")
    if value is None:
        return False
    if isinstance(value, bool):
        return value
    raise ValueError(f"{path}.regression_guard must be a boolean when present")


def _require_choice(item: dict, field: str, choices: frozenset[str], path: str) -> str:
    value = item.get(field)
    if not isinstance(value, str) or value not in choices:
        raise ValueError(f"{path}.{field} must be one of: {', '.join(sorted(choices))}")
    return value


def _validate_v2(item: dict, path: str, guard: bool) -> str:
    magnitude = _require_choice(item, "impact_magnitude", IMPACT_MAGNITUDES, path)
    scope = _require_choice(item, "affected_scope", AFFECTED_SCOPES, path)
    reversibility = _require_choice(item, "reversibility", REVERSIBILITIES, path)
    confidence = _require_choice(item, "confidence", CONFIDENCES, path)
    uncertainty = item.get("uncertainty")
    if not isinstance(uncertainty, str) or not uncertainty.strip():
        raise ValueError(f"{path}.uncertainty must be a non-empty string")
    return derive_priority_band_v2(
        item["impact"],
        magnitude,
        item["trigger_likelihood"],
        scope,
        reversibility,
        item["fix_cost"],
        confidence,
        regression_guard=guard,
    )


def validate_triage_item(item: dict, path: str, *, from_llm: bool = False) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    if "severity" in item:
        raise ValueError(
            f"{path}.severity is deprecated; use impact, trigger_likelihood, and fix_cost"
        )
    if from_llm and "priority_band" in item:
        raise ValueError(f"{path}.priority_band is derived by automation; do not emit from LLM")

    _require_choice(item, "impact", IMPACTS, path)
    trigger = _require_choice(item, "trigger_likelihood", TRIGGERS, path)
    _require_choice(item, "fix_cost", FIX_COSTS, path)

    guard = _parse_regression_guard(item, path)
    if guard and trigger == "fringe":
        raise ValueError(
            f"{path}.regression_guard must not be true when trigger_likelihood=fringe"
        )

    version = item.get("triage_version", 1)
    if version not in {1, TRIAGE_VERSION}:
        raise ValueError(f"{path}.triage_version must be 1 or {TRIAGE_VERSION}")
    if from_llm and version != TRIAGE_VERSION:
        raise ValueError(f"{path}.triage_version must be {TRIAGE_VERSION} for new model output")
    expected = (
        _validate_v2(item, path, guard)
        if version == TRIAGE_VERSION
        else derive_priority_band(
            item["impact"],
            trigger,
            item["fix_cost"],
            regression_guard=guard,
        )
    )
    actual = item.get("priority_band")
    if actual is not None and actual != expected:
        raise ValueError(f"{path}.priority_band must be {expected!r}, got {actual!r}")


def apply_triage_to_item(item: dict, path: str) -> None:
    validate_triage_item(item, path, from_llm=False)
    guard = _parse_regression_guard(item, path)
    item["priority_band"] = (
        _validate_v2(item, path, guard)
        if item.get("triage_version", 1) == TRIAGE_VERSION
        else derive_priority_band(
            item["impact"],
            item["trigger_likelihood"],
            item["fix_cost"],
            regression_guard=guard,
        )
    )


def apply_triage_to_retro(data: dict) -> None:
    if not isinstance(data, dict):
        raise ValueError("retro root must be an object")
    for key in FINDING_ARRAYS:
        items = data.get(key)
        if items is None:
            continue
        if not isinstance(items, list):
            raise ValueError(f"{key} must be an array")
        for index, item in enumerate(items):
            apply_triage_to_item(item, f"{key}[{index}]")


def _triage_fields(item: dict) -> dict[str, Any]:
    guard = _parse_regression_guard(item, "item")
    fields = {
        "impact": item.get("impact"),
        "trigger_likelihood": item.get("trigger_likelihood"),
        "fix_cost": item.get("fix_cost"),
        "regression_guard": guard,
        "priority_band": item.get("priority_band"),
    }
    if item.get("triage_version", 1) == TRIAGE_VERSION:
        fields.update(
            {
                "triage_version": TRIAGE_VERSION,
                "impact_magnitude": item.get("impact_magnitude"),
                "affected_scope": item.get("affected_scope"),
                "reversibility": item.get("reversibility"),
                "confidence": item.get("confidence"),
                "uncertainty": item.get("uncertainty"),
            }
        )
    return fields


def copy_triage_fields(item: dict, path: str = "item") -> dict[str, Any]:
    apply_triage_to_item(item, path)
    return _triage_fields(item)
