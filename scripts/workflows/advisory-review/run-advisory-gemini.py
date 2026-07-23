#!/usr/bin/env python3
"""Generate advisory review body via Gemini generateContent API (stdlib only)."""
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

    model = os.environ.get("GEMINI_ADVISORY_MODEL", "gemini-3.5-flash")
    prompt = open(prompt_path, encoding="utf-8").read()
    print(f"Gemini advisory review: model={model}", file=sys.stderr)

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

    candidates = body.get("candidates") or []
    if not candidates:
        print(f"Gemini returned no candidates: {body}", file=sys.stderr)
        return 1
    parts = (candidates[0].get("content") or {}).get("parts") or []
    if not parts or "text" not in parts[0]:
        block = candidates[0].get("finishReason", "unknown")
        print(f"Gemini returned no text (finishReason={block}): {body}", file=sys.stderr)
        return 1
    text = parts[0]["text"]

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(text)
    metadata_path = os.environ.get("ADVISORY_PROVIDER_METADATA_FILE")
    if metadata_path:
        with open(metadata_path, "w", encoding="utf-8") as fh:
            json.dump({"provider": "gemini", "model": model}, fh)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
