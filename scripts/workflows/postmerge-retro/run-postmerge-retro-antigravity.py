#!/usr/bin/env python3
"""Full-evidence post-merge retro via Gemini Interactions API (Antigravity)."""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

API_REVISION = "2026-05-20"
DEFAULT_AGENT = "antigravity-preview-05-2026"
# Interactions API payload guard — fall back to bounded when exceeded.
DEFAULT_PAYLOAD_LIMIT = 4_000_000


def read_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def inline_source(target: str, path: Path) -> dict:
    return {"type": "inline", "target": target, "content": read_file(path)}


def extract_output_text(body: dict) -> str:
    text = body.get("output_text") or body.get("outputText") or ""
    if text:
        return text
    outputs = body.get("outputs") or []
    chunks: list[str] = []
    for item in outputs:
        if isinstance(item, dict):
            if item.get("type") == "text" and item.get("text"):
                chunks.append(item["text"])
            elif item.get("text"):
                chunks.append(item["text"])
    return "\n".join(chunks).strip()


def payload_too_large(payload: dict, limit: int) -> bool:
    encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    return len(encoded) > limit


def main() -> int:
    if len(sys.argv) != 5:
        print(
            "Usage: run-postmerge-retro-antigravity.py "
            "<repo-root> <workdir> <prompt-file> <output-file>",
            file=sys.stderr,
        )
        return 2

    repo_root = Path(sys.argv[1]).resolve()
    workdir = Path(sys.argv[2]).resolve()
    prompt_path = Path(sys.argv[3])
    out_path = Path(sys.argv[4])

    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("GEMINI_API_KEY or GOOGLE_API_KEY required", file=sys.stderr)
        return 1

    agent = os.environ.get("ADVISORY_ANTIGRAVITY_AGENT", DEFAULT_AGENT)
    system_instruction = read_file(repo_root / ".github/prompts/post-merge-retro.md")
    task_input = read_file(prompt_path)

    sources: list[dict] = [
        inline_source(".agents/AGENTS.md", repo_root / "AGENTS.md"),
    ]
    context_list = workdir / "context-files.txt"
    if context_list.is_file():
        for rel in read_file(context_list).splitlines():
            rel = rel.strip()
            if not rel or rel == "AGENTS.md":
                continue
            abs_path = repo_root / rel
            if abs_path.is_file():
                sources.append(inline_source(f".agents/{rel}", abs_path))

    for target, filename in (
        (".workspace/pr-context/pr-body.md", "pr-body.md"),
        (".workspace/pr-context/changed-files.txt", "changed-files.txt"),
        (".workspace/pr-context/diff.patch", "diff.patch"),
        (".workspace/pr-context/summary.txt", "summary.txt"),
    ):
        path = workdir / filename
        if path.is_file():
            sources.append(inline_source(target, path))

    payload = {
        "agent": agent,
        "input": task_input,
        "system_instruction": system_instruction,
        "environment": {"type": "remote", "sources": sources},
    }

    limit = int(os.environ.get("POSTMERGE_RETRO_ANTIGRAVITY_PAYLOAD_LIMIT", DEFAULT_PAYLOAD_LIMIT))
    if payload_too_large(payload, limit):
        print(
            f"::warning::Antigravity retro payload exceeds {limit} bytes; caller should fall back to bounded",
            file=sys.stderr,
        )
        return 3

    url = "https://generativelanguage.googleapis.com/v1beta/interactions"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
            "Api-Revision": API_REVISION,
        },
        method="POST",
    )

    pr = "unknown"
    pr_json = workdir / "pr.json"
    if pr_json.is_file():
        try:
            pr = str(json.loads(read_file(pr_json)).get("number", "unknown"))
        except json.JSONDecodeError:
            pass

    print(f"Antigravity full-evidence retro: agent={agent} pr={pr}", file=sys.stderr)
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            body = json.load(resp)
    except urllib.error.HTTPError as exc:
        err = exc.read().decode("utf-8", errors="replace")
        print(f"Antigravity retro API error {exc.code}: {err}", file=sys.stderr)
        return 1

    text = extract_output_text(body)
    if not text:
        print(f"Antigravity retro returned no output text: {body}", file=sys.stderr)
        return 1

    out_path.write_text(text, encoding="utf-8")
    metadata_path = os.environ.get("ADVISORY_PROVIDER_METADATA_FILE")
    if metadata_path:
        model = f"agent:{agent}"
        Path(metadata_path).write_text(
            json.dumps(
                {
                    "provider": "antigravity",
                    "model": model,
                    "requested_model": model,
                    "observed_model": "unknown",
                }
            )
            + "\n",
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
