#!/usr/bin/env python3

import argparse
import copy
import json
import re
import sys
from pathlib import Path


INVENTORY = Path(".config/mcp-inventory.json")
GENERIC = Path(".mcp.json")
OPENCODE = Path(".opencode/opencode.json")


def merged(base: dict, override: dict) -> dict:
    result = copy.deepcopy(base)
    for key, value in override.items():
        if value is None:
            result.pop(key, None)
        elif isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merged(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def generic_server(spec: dict) -> dict:
    enabled = spec.get("enabled", True)
    if spec["transport"] == "remote":
        result = {"type": "http", "url": spec["url"]}
        if auth_env := spec.get("auth_env"):
            result["headers"] = {"Authorization": f"Bearer ${{{auth_env}}}"}
    else:
        command = spec.get("generic_command", spec["command"])
        result = {"command": command[0], "args": command[1:]}
        if environment := spec.get("environment"):
            result["env"] = {
                key: value if value == "ERROR" else f"${{{value}}}"
                for key, value in environment.items()
            }
    if not enabled:
        result["disabled"] = True
    return merged(result, spec.get("generic", {}))


def opencode_server(spec: dict, defaults: dict) -> dict:
    enabled = spec.get("enabled", True)
    if spec["transport"] == "remote":
        result = {"type": "remote", "url": spec["url"], "enabled": enabled}
        if auth_env := spec.get("auth_env"):
            result["oauth"] = False
            result["headers"] = {"Authorization": f"Bearer {{env:{auth_env}}}"}
    else:
        result = {"type": "local", "command": spec["command"], "enabled": enabled}
        if environment := spec.get("environment"):
            result["env"] = {
                key: value if value == "ERROR" else f"{{env:{value}}}"
                for key, value in environment.items()
            }
    return merged(merged(defaults, result), spec.get("opencode", {}))


def replace_json_object(text: str, key: str, value: dict) -> str:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*\{{', text)
    if not match:
        raise ValueError(f"missing top-level JSON object: {key}")
    start = text.index("{", match.start())
    depth = 0
    in_string = False
    escaped = False
    end = -1
    for index in range(start, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = index + 1
                break
    if end < 0:
        raise ValueError(f"unterminated top-level JSON object: {key}")
    rendered = json.dumps(value, indent=2)
    indented = rendered.splitlines()
    rendered = indented[0] + "\n" + "\n".join(f"  {line}" for line in indented[1:])
    return text[:start] + rendered + text[end:]


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate generic and OpenCode MCP configurations.")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    try:
        inventory_data = json.loads((args.repo / INVENTORY).read_text())
        inventory = inventory_data["servers"]
        opencode_defaults = inventory_data.get("defaults", {}).get("opencode", {})
        generic = json.dumps(
            {"mcpServers": {name: generic_server(spec) for name, spec in inventory.items()}},
            indent=2,
        ) + "\n"
        opencode_text = (args.repo / OPENCODE).read_text()
        opencode = replace_json_object(
            opencode_text,
            "mcp",
            {name: opencode_server(spec, opencode_defaults) for name, spec in inventory.items()},
        )
        json.loads(opencode)
    except (OSError, KeyError, ValueError, json.JSONDecodeError) as error:
        print(f"generate-mcp-configs: {error}", file=sys.stderr)
        return 2

    generated = {GENERIC: generic, OPENCODE: opencode}
    stale = [path for path, content in generated.items() if (args.repo / path).read_text() != content]
    if args.check:
        if not stale:
            return 0
        print(
            "stale generated MCP configurations: "
            + ", ".join(str(path) for path in stale)
            + f"; canonical source: {INVENTORY}; run: python3 scripts/generate-mcp-configs.py",
            file=sys.stderr,
        )
        return 1

    for path in stale:
        (args.repo / path).write_text(generated[path])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
