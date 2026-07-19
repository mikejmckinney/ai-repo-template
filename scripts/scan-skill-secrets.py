#!/usr/bin/env python3

import argparse
import json
import os
import re
import sys
from pathlib import Path


SIGNATURES = (
    ("private-key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("aws-access-key-id", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("github-token", re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{36,255}\b")),
    ("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("openai-api-key", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    ("slack-token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("stripe-secret-key", re.compile(r"\bsk_(?:live|test)_[A-Za-z0-9]{16,}\b")),
    ("npm-token", re.compile(r"\bnpm_[A-Za-z0-9]{36}\b")),
    ("pypi-token", re.compile(r"\bpypi-[A-Za-z0-9_-]{50,}\b")),
)
GENERIC_SECRET = re.compile(
    r"(?i)\b(?:api[_-]?key|client[_-]?secret|password|passwd|secret|token)\b"
    r"\s*[:=]\s*([\"'])([^\"']{16,})\1"
)
PLACEHOLDER_MARKERS = (
    "${",
    "<",
    "change",
    "example",
    "os.environ",
    "placeholder",
    "process.env",
    "replace",
    "sample",
    "your",
    "xxxx",
    "{env:",
)


def files_in(paths: list[Path]) -> list[Path]:
    files: set[Path] = set()
    for path in paths:
        if path.is_symlink():
            raise ValueError(f"refusing to scan symlink: {path}")
        if path.is_file():
            files.add(path)
            continue
        if not path.is_dir():
            raise ValueError(f"scan path does not exist: {path}")
        for root, directories, filenames in os.walk(path, followlinks=False):
            root_path = Path(root)
            for directory in directories:
                if (root_path / directory).is_symlink():
                    raise ValueError(f"refusing to scan symlink: {root_path / directory}")
            for filename in filenames:
                candidate = root_path / filename
                if candidate.is_symlink():
                    raise ValueError(f"refusing to scan symlink: {candidate}")
                if candidate.is_file():
                    files.add(candidate)
    return sorted(files)


def generic_secret(line: str) -> bool:
    match = GENERIC_SECRET.search(line)
    if match is None:
        return False
    value = match.group(2).lower()
    return not any(marker in value for marker in PLACEHOLDER_MARKERS)


def scan(paths: list[Path]) -> list[tuple[Path, int, str]]:
    findings = []
    for path in files_in(paths):
        data = path.read_bytes()
        if b"\0" in data:
            continue
        try:
            lines = data.decode("utf-8").splitlines()
        except UnicodeDecodeError as error:
            raise ValueError(f"cannot scan non-UTF-8 text file: {path}") from error
        for line_number, line in enumerate(lines, start=1):
            rules = [name for name, pattern in SIGNATURES if pattern.search(line)]
            if generic_secret(line):
                rules.append("generic-secret-assignment")
            findings.extend((path, line_number, rule) for rule in sorted(set(rules)))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan refreshed skill packages for credentials")
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    try:
        findings = scan(args.paths)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    for path, line_number, rule in findings:
        print(f"{path}:{line_number}: {rule}")
    print(json.dumps({"status": "success" if not findings else "findings", "findings": len(findings)}))
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
