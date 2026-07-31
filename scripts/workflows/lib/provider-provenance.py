#!/usr/bin/env python3
"""Normalize automation-owned provider and model provenance."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


UNKNOWN_PROVENANCE = {
    "version": 1,
    "provider": "unknown",
    "requested_model": "unknown",
    "observed_model": "unknown",
}


def _nonempty(value: object) -> str:
    return str(value or "").strip()


def normalize_provider_metadata(metadata: dict) -> dict:
    if not isinstance(metadata, dict):
        raise ValueError("provider metadata must be an object")
    provider = _nonempty(metadata.get("provider"))
    if not provider:
        raise ValueError("provider metadata requires provider")

    requested = _nonempty(metadata.get("requested_model")) or _nonempty(
        metadata.get("model")
    )
    if not requested:
        requested = "unknown"

    observed = _nonempty(metadata.get("observed_model")) or "unknown"

    return {
        "version": 1,
        "provider": provider,
        "requested_model": requested,
        "observed_model": observed,
    }


def validate_provenance(value: object, path: str = "provenance") -> None:
    if not isinstance(value, dict):
        raise ValueError(f"{path} must be an object")
    if value.get("version") != 1:
        raise ValueError(f"{path}.version must be 1")
    expected = {"version", "provider", "requested_model", "observed_model"}
    extra = set(value) - expected
    if extra:
        raise ValueError(f"{path} contains unsupported fields: {sorted(extra)}")
    for key in ("provider", "requested_model", "observed_model"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            raise ValueError(f"{path}.{key} must be a non-empty string")


def validate_provider_attempts(
    value: object,
    path: str = "provider_attempts",
    *,
    allowed_extra_fields: set[str] | None = None,
) -> None:
    if not isinstance(value, list):
        raise ValueError(f"{path} must be an array")
    allowed = {"provider", "status"} | (allowed_extra_fields or set())
    for index, attempt in enumerate(value):
        item_path = f"{path}[{index}]"
        if not isinstance(attempt, dict):
            raise ValueError(f"{item_path} must be an object")
        extra = set(attempt) - allowed
        if extra:
            raise ValueError(f"{item_path} contains unsupported fields: {sorted(extra)}")
        provider = attempt.get("provider")
        if not isinstance(provider, str) or not provider.strip():
            raise ValueError(f"{item_path}.provider must be a non-empty string")
        if attempt.get("status") not in {"success", "failed"}:
            raise ValueError(f"{item_path}.status must be success or failed")
        for field in allowed - {"provider", "status"}:
            if not isinstance(attempt.get(field), str) or not attempt[field].strip():
                raise ValueError(f"{item_path}.{field} must be a non-empty string")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    normalize = subparsers.add_parser("normalize")
    normalize.add_argument("metadata", type=Path)
    args = parser.parse_args()

    try:
        metadata = json.loads(args.metadata.read_text(encoding="utf-8"))
        value = normalize_provider_metadata(metadata)
        validate_provenance(value)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"provider provenance error: {error}", file=sys.stderr)
        return 1

    json.dump(value, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
