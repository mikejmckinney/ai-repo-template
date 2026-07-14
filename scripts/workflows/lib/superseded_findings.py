"""Shared narrow detection for missing-path findings already resolved on main."""
from __future__ import annotations

import re
from pathlib import Path

MISSING_HINTS = (
    "missing",
    "absent",
    "not found",
    "does not exist",
    "doesn't exist",
    "lack ",
    "without ",
    "no longer present",
)


def _is_path_char(char: str) -> bool:
    return char.isalnum() or char in "/._-"


def path_token_in_text(path: str, text: str) -> bool:
    norm = path.strip().lstrip("./")
    if not norm:
        return False
    start = 0
    while True:
        index = text.find(norm, start)
        if index == -1:
            return False
        before_ok = index == 0 or not _is_path_char(text[index - 1])
        after_index = index + len(norm)
        after_ok = after_index >= len(text) or not _is_path_char(text[after_index])
        if before_ok and after_ok:
            return True
        start = index + 1


def finding_text(finding: dict) -> str:
    parts = [
        finding.get("body") or "",
        finding.get("title") or "",
        " ".join(str(value) for value in finding.get("evidence") or []),
        " ".join(str(value) for value in finding.get("repro_steps") or []),
    ]
    return "\n".join(parts)


def check_superseded(
    finding: dict, candidate_paths: list[str], repo_root: Path
) -> tuple[bool, str]:
    if finding.get("category") != "follow_up_issues":
        return False, ""
    blob = finding_text(finding)
    if not any(hint in blob.lower() for hint in MISSING_HINTS):
        return False, ""

    paths = [
        path
        for path in candidate_paths
        if path and path_token_in_text(path, blob)
    ]
    if not paths:
        for match in re.findall(r"`([^`]+)`", blob):
            candidate = match.strip()
            if ("/" in candidate or "." in candidate) and path_token_in_text(candidate, blob):
                paths.append(candidate)

    for relative in paths:
        relative = relative.strip().lstrip("./")
        if not relative or relative.startswith("http"):
            continue
        target = repo_root / relative
        if target.is_file() or target.is_dir():
            kind = "directory" if target.is_dir() else "file"
            return (
                True,
                f"{relative} exists on main HEAD as {kind} "
                "(finding described missing/absent state)",
            )
    return False, ""
