#!/usr/bin/env python3
"""Generate weekly repo review JSON via Gemini Interactions API (Antigravity agent)."""
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
            "Usage: run-weekly-antigravity.py <repo-root> <workdir> <output-file>",
            file=sys.stderr,
        )
        return 2

    repo_root, workdir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("GEMINI_API_KEY or GOOGLE_API_KEY required", file=sys.stderr)
        return 1

    agent = os.environ.get("ADVISORY_ANTIGRAVITY_AGENT", DEFAULT_AGENT)
    prompt_path = os.path.join(repo_root, ".github/prompts/weekly-repo-review.md")
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
                sources.append(inline_source(f".agents/{rel}", abs_path))

    meta_path = os.path.join(workdir, "run-meta.md")
    meta = read_file(meta_path) if os.path.isfile(meta_path) else ""

    task_input = "\n".join(
        [
            "Perform a weekly full-repo health review on main using mounted governance context.",
            "Inspect the repository as needed via the remote agent environment.",
            "Follow weekly-repo-review.md (system instruction).",
            "Return **valid JSON only** matching the required weekly review shape.",
            "",
            meta,
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

    print(f"Antigravity weekly review: agent={agent}", file=sys.stderr)
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
    metadata_path = os.environ.get("ADVISORY_PROVIDER_METADATA_FILE")
    if metadata_path:
        model = f"agent:{agent}"
        with open(metadata_path, "w", encoding="utf-8") as fh:
            json.dump(
                {
                    "provider": "antigravity",
                    "model": model,
                    "requested_model": model,
                    "observed_model": "unknown",
                },
                fh,
            )
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
