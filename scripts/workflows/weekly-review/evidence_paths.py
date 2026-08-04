"""Validation for weekly finding evidence paths."""
from __future__ import annotations

import re
from pathlib import PurePosixPath


def validate_evidence_paths(item: dict, item_path: str) -> None:
    evidence = item.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        raise ValueError(f"{item_path}.evidence must be a non-empty array")
    for index, value in enumerate(evidence):
        path = f"{item_path}.evidence[{index}]"
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{path} must be a non-empty string")
        raw = value.strip()
        parts = raw.split("/")
        if (
            raw.startswith(("/", "~", "\\"))
            or "\\" in raw
            or "://" in raw
            or re.match(r"^[A-Za-z]:[/\\]", raw)
            or any(part in (".", "..") for part in parts)
            or str(PurePosixPath(raw)) in ("", ".")
        ):
            raise ValueError(f"{path} must be a safe repository-relative path")
