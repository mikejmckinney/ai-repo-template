#!/usr/bin/env python3
"""Derive priority_band from retro finding triage fields (stdlib only)."""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any

IMPACTS = frozenset({"incorrect-behavior", "dx-perf-doc", "meta-harness"})
TRIGGERS = frozenset({"common", "edge", "fringe"})
FIX_COSTS = frozenset({"trivial", "moderate", "large"})
BANDS = frozenset({"fix-now", "should-fix", "defer"})

FINDING_ARRAYS = ("follow_up_issues", "adr_updates", "context_pack_updates")


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
    val = item.get("regression_guard")
    if val is None:
        return False
    if isinstance(val, bool):
        return val
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
        raise ValueError(f"{path}.regression_guard must not be true when trigger_likelihood=fringe")

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
        arr = data.get(key)
        if arr is None:
            continue
        if not isinstance(arr, list):
            raise ValueError(f"{key} must be an array")
        for i, item in enumerate(arr):
            apply_triage_to_item(item, f"{key}[{i}]")


def _triage_fields(item: dict) -> dict[str, Any]:
    guard = _parse_regression_guard(item, "")
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
    """Return triage fields for daily finding rows (merge path)."""
    apply_triage_to_item(item, path)
    return _triage_fields(item)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--impact", choices=sorted(IMPACTS))
    parser.add_argument("--trigger", choices=sorted(TRIGGERS), dest="trigger_likelihood")
    parser.add_argument("--fix-cost", choices=sorted(FIX_COSTS), dest="fix_cost")
    parser.add_argument(
        "--guard",
        choices=("true", "false"),
        default="false",
        help="regression_guard (default false)",
    )
    parser.add_argument(
        "retro_json",
        nargs="?",
        help="Optional retro.json to validate and stamp priority_band in place",
    )
    args = parser.parse_args()

    if args.retro_json:
        data = json.loads(open(args.retro_json, encoding="utf-8").read())
        apply_triage_to_retro(data)
        with open(args.retro_json, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        return 0

    if not args.impact or not args.trigger_likelihood or not args.fix_cost:
        parser.error("provide --impact --trigger --fix-cost, or a retro_json path")
    band = derive_priority_band(
        args.impact,
        args.trigger_likelihood,
        args.fix_cost,
        regression_guard=args.guard == "true",
    )
    print(band)
    return 0


if __name__ == "__main__":
    sys.exit(main())
