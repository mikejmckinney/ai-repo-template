#!/usr/bin/env python3

import argparse
import os
import uuid
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--redact-env", action="append", default=[])
    args = parser.parse_args()

    session_id = str(uuid.UUID(args.session_id))
    projects_dir = Path.home() / ".claude" / "projects"
    matches = [
        path
        for path in projects_dir.glob(f"*/{session_id}.jsonl")
        if path.is_file() and not path.is_symlink()
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"expected one persisted Claude session for {session_id}, found {len(matches)}"
        )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    transcript = matches[0].read_text(encoding="utf-8")
    for name in args.redact_env:
        value = os.environ.get(name, "")
        if len(value) >= 8:
            transcript = transcript.replace(value, f"[REDACTED:{name}]")
    output.write_text(transcript, encoding="utf-8")
    output.chmod(0o600)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
