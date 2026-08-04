#!/usr/bin/env python3
"""Exercise the repository Open Design stdio MCP without spawning an agent."""

from __future__ import annotations

import json
import select
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
TIMEOUT_SECONDS = 30


def send(process: subprocess.Popen[str], payload: dict[str, Any]) -> None:
    assert process.stdin is not None
    process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
    process.stdin.flush()


def receive(process: subprocess.Popen[str], request_id: int) -> dict[str, Any]:
    assert process.stdout is not None
    deadline = time.monotonic() + TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        ready, _, _ = select.select([process.stdout], [], [], 0.5)
        if not ready:
            if process.poll() is not None:
                raise RuntimeError(f"MCP exited with status {process.returncode}")
            continue
        line = process.stdout.readline()
        if not line:
            continue
        message = json.loads(line)
        if message.get("id") == request_id:
            if "error" in message:
                raise RuntimeError(json.dumps(message["error"], sort_keys=True))
            return message["result"]
    raise TimeoutError(f"Open Design MCP request {request_id} timed out")


def request(
    process: subprocess.Popen[str],
    request_id: int,
    method: str,
    params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method,
    }
    if params is not None:
        payload["params"] = params
    send(process, payload)
    return receive(process, request_id)


def main() -> int:
    process = subprocess.Popen(
        ["bash", str(ROOT / "scripts/open-design-mcp.sh")],
        cwd=ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    try:
        initialized = request(
            process,
            1,
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "repository-smoke-test", "version": "1"},
            },
        )
        send(process, {"jsonrpc": "2.0", "method": "notifications/initialized"})
        resources = request(process, 2, "resources/list")
        tools = request(process, 3, "tools/list")
        skills = request(
            process,
            4,
            "tools/call",
            {"name": "list_skills", "arguments": {}},
        )
        projects = request(
            process,
            5,
            "tools/call",
            {"name": "list_projects", "arguments": {}},
        )

        resource_count = len(resources.get("resources", []))
        tool_names = {tool["name"] for tool in tools.get("tools", [])}
        if resource_count < 1:
            raise RuntimeError("Open Design MCP returned no resources")
        if not {"list_skills", "list_projects"}.issubset(tool_names):
            raise RuntimeError("Open Design MCP is missing discovery tools")
        if skills.get("isError") or projects.get("isError"):
            raise RuntimeError("Open Design discovery tool returned an error")

        server = initialized.get("serverInfo", {})
        print(
            "Open Design MCP smoke passed: "
            f"server={server.get('name')} {server.get('version')}, "
            f"resources={resource_count}, tools={len(tool_names)}"
        )
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, TimeoutError, json.JSONDecodeError) as error:
        print(f"Open Design MCP smoke failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
