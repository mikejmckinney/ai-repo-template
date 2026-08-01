#!/usr/bin/env python3
"""Create a provider batch containing only safely verifiable findings."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from verification_capability import is_fix_eligible, routing_reason


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: route-fixable-findings.py <batch.json> <routed.json>", file=sys.stderr)
        return 2
    source, destination = map(Path, sys.argv[1:])
    payload = json.loads(source.read_text(encoding="utf-8"))
    findings = payload.get("findings")
    if not isinstance(payload, dict) or not isinstance(findings, list):
        print("batch must be an object with a findings array", file=sys.stderr)
        return 1

    eligible = []
    deferred = []
    for finding in findings:
        if not isinstance(finding, dict):
            continue
        if is_fix_eligible(finding):
            eligible.append(finding)
            continue
        deferred.append(
            {
                "dedupe_key": str(finding.get("dedupe_key") or "unknown"),
                "routing_reason": routing_reason(finding)
                or "finding is superseded or outside automated fix priority",
            }
        )

    routed = {**payload, "findings": eligible, "deferred_findings": deferred}
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(routed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Routed {len(eligible)} finding(s); deferred {len(deferred)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
