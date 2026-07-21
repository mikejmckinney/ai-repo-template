"""Shared narrow detection for missing-path findings already resolved on main."""
from __future__ import annotations

import re
import sys
from pathlib import Path

MISSING_PHRASES = (
    "missing",
    "absent",
    "not found",
    "does not exist",
    "doesn't exist",
    "no longer present",
)


def _is_path_char(char: str) -> bool:
    return char.isalnum() or char in "/._-"


def _path_reference(path: str) -> str:
    norm = path.strip()
    while norm.startswith("./"):
        norm = norm[2:]
    return norm


def path_token_in_text(path: str, text: str) -> bool:
    norm = _path_reference(path)
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


def _claims_path_is_missing(path: str, text: str) -> bool:
    norm = _path_reference(path)
    start = 0
    lowered = text.lower()
    while True:
        index = text.find(norm, start)
        if index == -1:
            return False
        before_ok = index == 0 or not _is_path_char(text[index - 1])
        after_index = index + len(norm)
        after_ok = after_index >= len(text) or not _is_path_char(text[after_index])
        if before_ok and after_ok:
            before = lowered[max(0, index - 40) : index].rstrip("`'\" :—-\n\t")
            after = lowered[after_index : after_index + 50].lstrip("`'\" :—-\n\t")
            for prefix in ("is ", "was ", "appears to be "):
                if after.startswith(prefix):
                    after = after[len(prefix) :]
                    break
            if any(after.startswith(phrase) for phrase in MISSING_PHRASES):
                return True
            if re.search(r"(?:missing|absent|not found)(?: file| directory| path)?$", before):
                return True
        start = index + 1


def _contained_target(candidate: str, repo_root: Path) -> tuple[Path | None, str]:
    raw = candidate.strip()
    path = Path(raw)
    if path.is_absolute():
        return None, "absolute path candidate is outside repository"
    if ".." in path.parts:
        return None, f"candidate {raw!r} uses traversal outside repository"
    while raw.startswith("./"):
        raw = raw[2:]
    if not raw:
        return None, "empty path candidate is outside repository"
    target = (repo_root / raw).resolve()
    try:
        target.relative_to(repo_root)
    except ValueError:
        return None, f"candidate {raw!r} resolves outside repository"
    return target, raw


def check_superseded(
    finding: dict, candidate_paths: list[str], repo_root: Path
) -> tuple[bool, str]:
    if finding.get("category") != "follow_up_issues":
        return False, ""
    repo_root = repo_root.resolve()
    blob = finding_text(finding)

    paths = [
        path
        for path in candidate_paths
        if path and path_token_in_text(path, blob) and _claims_path_is_missing(path, blob)
    ]
    if not paths:
        for match in re.findall(r"`([^`]+)`", blob):
            candidate = match.strip()
            if (
                ("/" in candidate or "." in candidate)
                and path_token_in_text(candidate, blob)
                and _claims_path_is_missing(candidate, blob)
            ):
                paths.append(candidate)

    for relative in paths:
        if relative.strip().startswith(("http://", "https://")):
            continue
        target, result = _contained_target(relative, repo_root)
        if target is None:
            print(f"::warning::superseded-check: rejected {result}", file=sys.stderr)
            continue
        if target.is_file() or target.is_dir():
            kind = "directory" if target.is_dir() else "file"
            return (
                True,
                f"{result} exists on main HEAD as {kind} "
                "(finding described missing/absent state)",
            )
    return False, ""
