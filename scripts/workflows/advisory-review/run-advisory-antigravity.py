#!/usr/bin/env python3
"""Generate advisory review via Gemini Interactions API (Antigravity agent, stdlib only)."""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

API_REVISION = "2026-05-20"
DEFAULT_AGENT = "antigravity-preview-05-2026"


def read_file(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def inline_source(target: str, path: str) -> dict:
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


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: run-advisory-antigravity.py <repo-root> <workdir> <output-file>",
            file=sys.stderr,
        )
        return 2

    repo_root, workdir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("GEMINI_API_KEY or GOOGLE_API_KEY required", file=sys.stderr)
        return 1

    agent = os.environ.get("ADVISORY_ANTIGRAVITY_AGENT", DEFAULT_AGENT)
    prompt_path = os.path.join(repo_root, ".github/prompts/pr-advisory-review.md")
    system_instruction = read_file(prompt_path)

    sources: list[dict] = [
        inline_source(".agents/AGENTS.md", os.path.join(repo_root, "AGENTS.md")),
    ]
    context_list = os.path.join(workdir, "context-files.txt")
    if os.path.isfile(context_list):
        for rel in read_file(context_list).splitlines():
            rel = rel.strip()
            if not rel or rel == "AGENTS.md":
                continue
            abs_path = os.path.join(repo_root, rel)
            if os.path.isfile(abs_path):
                mount_rel = rel.lstrip("./")
                if mount_rel.startswith("."):
                    mount_rel = mount_rel[1:]
                sources.append(inline_source(f".agents/{mount_rel}", abs_path))

    sources.extend(
        [
            inline_source(
                ".workspace/pr-context/pr-body.md",
                os.path.join(workdir, "pr-body.md"),
            ),
            inline_source(
                ".workspace/pr-context/changed-files.txt",
                os.path.join(workdir, "changed-files.txt"),
            ),
            inline_source(
                ".workspace/pr-context/diff.patch",
                os.path.join(workdir, "full.diff"),
            ),
        ]
    )

    coverage_path = os.path.join(workdir, "diff-coverage.md")
    coverage = read_file(coverage_path) if os.path.isfile(coverage_path) else ""

    task_input = "\n".join(
        [
            "Perform a non-blocking advisory PR review using the mounted workspace files.",
            "Follow pr-advisory-review.md (system instruction) and mounted AGENTS/rules sources.",
            "Return only the markdown structure required by pr-advisory-review.md.",
            "Include the session handshake and context receipt as specified.",
            "",
            coverage,
        ]
    ).strip()

    payload = {
        "agent": agent,
        "input": task_input,
        "system_instruction": system_instruction,
        "environment": {"type": "remote", "sources": sources},
    }

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

    print(f"Antigravity advisory review: agent={agent}", file=sys.stderr)
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            body = json.load(resp)
    except urllib.error.HTTPError as exc:
        err = exc.read().decode("utf-8", errors="replace")
        print(f"Antigravity API error {exc.code}: {err}", file=sys.stderr)
        return 1

    text = extract_output_text(body)
    if not text:
        print(f"Antigravity returned no output text: {body}", file=sys.stderr)
        return 1

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
