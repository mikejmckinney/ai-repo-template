#!/usr/bin/env python3
"""Loopback-only official A2A v1.0 JSON-RPC echo server for preflight."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import uvicorn
from a2a.helpers import new_data_message
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.routes import create_agent_card_routes, create_jsonrpc_routes
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import AgentCapabilities, AgentCard, AgentInterface, AgentSkill, Role
from google.protobuf import json_format
from starlette.applications import Starlette


class EchoExecutor(AgentExecutor):
    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        if context.message is None or len(context.message.parts) != 1:
            raise ValueError("expected one structured message part")
        value = json_format.MessageToDict(context.message.parts[0].data)
        await event_queue.enqueue_event(
            new_data_message(value, media_type="application/json", role=Role.ROLE_AGENT)
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError("preflight immediate responses cannot be canceled")


class A2AVersionMiddleware:
    """Reject POST requests that do not carry the required A2A wire version."""

    def __init__(self, app: Any, evidence_file: Path):
        self.app = app
        self.evidence_file = evidence_file

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] == "http" and scope["method"] == "POST":
            headers = dict(scope["headers"])
            observed = headers.get(b"a2a-version", b"").decode("ascii", errors="replace")
            if observed != "1.0":
                await send(
                    {
                        "type": "http.response.start",
                        "status": 400,
                        "headers": [(b"content-type", b"text/plain")],
                    }
                )
                await send(
                    {
                        "type": "http.response.body",
                        "body": b"A2A-Version must be 1.0",
                    }
                )
                return
            self.evidence_file.write_text(observed, encoding="utf-8")
        await self.app(scope, receive, send)


def build_app(port: int, evidence_file: Path) -> A2AVersionMiddleware:
    card = AgentCard(
        name="Phase 0C Canonical Event Echo",
        description="Loopback-only no-spend structured event preflight.",
        version="preflight-fixture-1",
        default_input_modes=["application/json"],
        default_output_modes=["application/json"],
        capabilities=AgentCapabilities(streaming=False),
        supported_interfaces=[
            AgentInterface(
                protocol_binding="JSONRPC",
                protocol_version="1.0",
                url=f"http://127.0.0.1:{port}/",
            )
        ],
        skills=[
            AgentSkill(
                id="canonical-event-echo",
                name="Canonical event echo",
                description="Returns one structured canonical event.",
                tags=["benchmark", "preflight"],
                input_modes=["application/json"],
                output_modes=["application/json"],
            )
        ],
    )
    handler = DefaultRequestHandler(
        agent_executor=EchoExecutor(), task_store=InMemoryTaskStore(), agent_card=card
    )
    routes = [
        *create_agent_card_routes(card),
        *create_jsonrpc_routes(handler, "/"),
    ]
    return A2AVersionMiddleware(Starlette(routes=routes), evidence_file)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--header-evidence-file", type=Path, required=True)
    args = parser.parse_args()
    uvicorn.run(
        build_app(args.port, args.header_evidence_file),
        host="127.0.0.1",
        port=args.port,
        log_level="error",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
