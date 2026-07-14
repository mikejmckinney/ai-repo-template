"""Canonical finding triage validation and priority derivation."""
from __future__ import annotations

from typing import Any

IMPACTS = frozenset({"incorrect-behavior", "dx-perf-doc", "meta-harness"})
TRIGGERS = frozenset({"common", "edge", "fringe"})
FIX_COSTS = frozenset({"trivial", "moderate", "large"})
BANDS = frozenset({"fix-now", "should-fix", "defer"})

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


def _parse_regression_guard(item: dict, path: str) -> bool:
    if "regression_guard" not in item:
        return False
    value = item.get("regression_guard")
    if value is None:
        return False
    if isinstance(value, bool):
        return value
    raise ValueError(f"{path}.regression_guard must be a boolean when present")


def validate_triage_item(item: dict, path: str, *, from_llm: bool = False) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    if item.get("severity") is not None:
        raise ValueError(
            f"{path}.severity is deprecated; use impact, trigger_likelihood, and fix_cost"
        )
    if from_llm and item.get("priority_band") is not None:
        raise ValueError(f"{path}.priority_band is derived by automation; do not emit from LLM")

    impact = item.get("impact")
    if not isinstance(impact, str) or impact not in IMPACTS:
        raise ValueError(f"{path}.impact must be one of: {', '.join(sorted(IMPACTS))}")

    trigger = item.get("trigger_likelihood")
    if not isinstance(trigger, str) or trigger not in TRIGGERS:
        raise ValueError(
            f"{path}.trigger_likelihood must be one of: {', '.join(sorted(TRIGGERS))}"
        )

    fix_cost = item.get("fix_cost")
    if not isinstance(fix_cost, str) or fix_cost not in FIX_COSTS:
        raise ValueError(f"{path}.fix_cost must be one of: {', '.join(sorted(FIX_COSTS))}")

    guard = _parse_regression_guard(item, path)
    if guard and trigger == "fringe":
        raise ValueError(
            f"{path}.regression_guard must not be true when trigger_likelihood=fringe"
        )

    expected = derive_priority_band(impact, trigger, fix_cost, regression_guard=guard)
    actual = item.get("priority_band")
    if actual is not None and actual != expected:
        raise ValueError(f"{path}.priority_band must be {expected!r}, got {actual!r}")


def apply_triage_to_item(item: dict, path: str) -> None:
    validate_triage_item(item, path, from_llm=False)
    guard = _parse_regression_guard(item, path)
    item["priority_band"] = derive_priority_band(
        item["impact"],
        item["trigger_likelihood"],
        item["fix_cost"],
        regression_guard=guard,
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
    return {
        "impact": item.get("impact"),
        "trigger_likelihood": item.get("trigger_likelihood"),
        "fix_cost": item.get("fix_cost"),
        "regression_guard": guard,
        "priority_band": item.get("priority_band")
        or derive_priority_band(
            item["impact"],
            item["trigger_likelihood"],
            item["fix_cost"],
            regression_guard=guard,
        ),
    }


def copy_triage_fields(item: dict, path: str = "item") -> dict[str, Any]:
    apply_triage_to_item(item, path)
    return _triage_fields(item)
