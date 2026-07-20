#!/usr/bin/env python3

import argparse
import copy
import json
import sys
from pathlib import Path


RUNTIME_DIR = Path(".github/agent-runtime")
BASE = RUNTIME_DIR / "base.json"
PROFILES = {
    "review": RUNTIME_DIR / "review.overlay.json",
    "fix": RUNTIME_DIR / "fix.overlay.json",
}


def merged(base: dict, overlay: dict) -> dict:
    result = copy.deepcopy(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merged(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def encoded(data: dict) -> str:
    return json.dumps(data, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate locked agent runtime profiles.")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    try:
        base = json.loads((args.repo / BASE).read_text())
        generated = {
            RUNTIME_DIR / f"{name}.json": encoded(
                merged(base, json.loads((args.repo / overlay).read_text()))
            )
            for name, overlay in PROFILES.items()
        }
    except (OSError, json.JSONDecodeError) as error:
        print(f"generate-agent-runtime: {error}", file=sys.stderr)
        return 2

    stale = [path for path, content in generated.items() if (args.repo / path).read_text() != content]
    if args.check:
        if not stale:
            return 0
        print(
            "stale generated runtime profiles: "
            + ", ".join(str(path) for path in stale)
            + f"; sources: {BASE} and overlays; run: python3 scripts/generate-agent-runtime.py",
            file=sys.stderr,
        )
        return 1

    for path in stale:
        (args.repo / path).write_text(generated[path])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
