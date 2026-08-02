#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import uuid
from pathlib import Path
from typing import Iterator


def tool_uses(value: object) -> Iterator[dict]:
    if isinstance(value, list):
        for item in value:
            yield from tool_uses(item)
        return
    if not isinstance(value, dict):
        return
    if value.get("type") == "tool_use" and isinstance(value.get("name"), str):
        yield value
        return
    for key in ("message", "content"):
        if key in value:
            yield from tool_uses(value[key])


def session_path(session_id: str) -> Path:
    matches = [
        path
        for path in (Path.home() / ".claude" / "projects").glob(
            f"*/{session_id}.jsonl"
        )
        if path.is_file() and not path.is_symlink()
    ]
    if len(matches) != 1:
        raise ValueError(
            f"expected one persisted Claude session for {session_id}, found {len(matches)}"
        )
    return matches[0]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    session_id = str(uuid.UUID(args.session_id))
    repo_root = Path(args.repo_root).resolve()
    paths: list[str] = []
    directories: list[str] = []
    tools: list[str] = []
    github_calls = 0

    with session_path(session_id).open(encoding="utf-8") as transcript:
        for line_number, line in enumerate(transcript, start=1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"invalid Claude session JSON at line {line_number}: {exc}"
                ) from exc
            for tool in tool_uses(record):
                name = tool["name"]
                if name not in tools:
                    tools.append(name)
                if name.startswith("mcp__github_read__"):
                    github_calls += 1
                    continue
                inputs = tool.get("input")
                if not isinstance(inputs, dict):
                    continue
                raw_path = inputs.get("file_path") if name == "Read" else inputs.get("path") if name == "Grep" else None
                if not isinstance(raw_path, str) or not raw_path.strip():
                    continue
                candidate = Path(raw_path)
                if not candidate.is_absolute():
                    candidate = repo_root / candidate
                resolved = str(candidate.resolve())
                if name == "Grep" and candidate.resolve().is_dir():
                    if resolved not in directories:
                        directories.append(resolved)
                elif resolved not in paths:
                    paths.append(resolved)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(
            {
                "session_id": session_id,
                "paths": paths,
                "directories": directories,
                "github_calls": github_calls,
                "tools": tools,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
