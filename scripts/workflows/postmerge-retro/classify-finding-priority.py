#!/usr/bin/env python3
"""CLI compatibility wrapper for the shared finding-priority module."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

LIB_DIR = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB_DIR))

from finding_priority import (  # noqa: E402,F401
    AFFECTED_SCOPES,
    BANDS,
    CONFIDENCES,
    FINDING_ARRAYS,
    FIX_COSTS,
    IMPACT_MAGNITUDES,
    IMPACTS,
    REVERSIBILITIES,
    SURFACES,
    TRIGGERS,
    apply_triage_to_item,
    apply_triage_to_retro,
    copy_triage_fields,
    derive_priority_band,
    derive_priority_band_v2,
    derive_surface_action,
    validate_triage_item,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--impact", choices=sorted(IMPACTS))
    parser.add_argument("--impact-magnitude", choices=sorted(IMPACT_MAGNITUDES))
    parser.add_argument("--trigger", choices=sorted(TRIGGERS), dest="trigger_likelihood")
    parser.add_argument("--fix-cost", choices=sorted(FIX_COSTS), dest="fix_cost")
    parser.add_argument("--affected-scope", choices=sorted(AFFECTED_SCOPES))
    parser.add_argument("--reversibility", choices=sorted(REVERSIBILITIES))
    parser.add_argument("--confidence", choices=sorted(CONFIDENCES))
    parser.add_argument("--uncertainty")
    parser.add_argument("--surface", choices=sorted(SURFACES))
    parser.add_argument("--triage-version", choices=(1, 2), type=int, default=1)
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
    if args.triage_version == 2:
        required = {
            "--impact-magnitude": args.impact_magnitude,
            "--affected-scope": args.affected_scope,
            "--reversibility": args.reversibility,
            "--confidence": args.confidence,
            "--uncertainty": args.uncertainty,
            "--surface": args.surface,
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            parser.error(f"triage version 2 requires: {', '.join(missing)}")
        band = derive_priority_band_v2(
            args.impact,
            args.impact_magnitude,
            args.trigger_likelihood,
            args.affected_scope,
            args.reversibility,
            args.fix_cost,
            args.confidence,
            regression_guard=args.guard == "true",
        )
        print(
            json.dumps(
                {
                    "triage_version": 2,
                    "priority_band": band,
                    "surface_action": derive_surface_action(band, args.surface),
                },
                sort_keys=True,
            )
        )
    else:
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
