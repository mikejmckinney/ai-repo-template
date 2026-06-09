#!/usr/bin/env python3
"""Generate advisory review body via Gemini API (stdlib only)."""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: run-advisory-gemini.py <prompt-file> <output-file>", file=sys.stderr)
        return 2

    prompt_path, out_path = sys.argv[1], sys.argv[2]
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("GEMINI_API_KEY or GOOGLE_API_KEY required", file=sys.stderr)
        return 1

    model = os.environ.get("GEMINI_ADVISORY_MODEL", "gemini-2.5-flash")
    prompt = open(prompt_path, encoding="utf-8").read()

    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={api_key}"
    )
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.2},
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            body = json.load(resp)
    except urllib.error.HTTPError as exc:
        err = exc.read().decode("utf-8", errors="replace")
        print(f"Gemini API error {exc.code}: {err}", file=sys.stderr)
        return 1

    try:
        text = body["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        print(f"Unexpected Gemini response shape: {exc}\n{body}", file=sys.stderr)
        return 1

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
