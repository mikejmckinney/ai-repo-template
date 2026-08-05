#!/usr/bin/env python3
"""Validate Phase 0C and exercise official A2A transport without paid work."""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import importlib.metadata
import json
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from phase_0c_freeze import validate_treatment_pair
from phase_0c_gate import canonical_bytes, evaluate_graph, sha256
from phase_0c_transport import (
    CanonicalFixtureAdapter,
    normalize_ledger,
    require_equal_suppressed,
)


SDK_VERSION = "1.1.2"
PROTOCOL_VERSION = "1.0"
SPECIFICATION_RELEASE = "1.0.0"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_document(document: Any, schema_path: Path) -> None:
    schema = load_json(schema_path)
    event_path = schema_path.parent / "event.schema.json"
    registry = Registry()
    if event_path.exists():
        event_resource = Resource.from_contents(load_json(event_path))
        registry = registry.with_resources(
            [
                (event_path.resolve().as_uri(), event_resource),
                ("event.schema.json", event_resource),
            ]
        )
    validator = Draft202012Validator(schema, registry=registry)
    errors = sorted(validator.iter_errors(document), key=lambda error: list(error.path))
    if errors:
        raise ValueError(f"{schema_path.name}: {errors[0].message}")


def validate_apparatus(manifest_path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    namespace = manifest_path.parent
    repo_root = Path(__file__).resolve().parents[3]
    manifest = load_json(manifest_path)
    validate_document(manifest, namespace / "manifest.schema.json")
    expected_python = tuple(int(part) for part in manifest["dependency_lock"]["python_version"].split("."))
    if sys.version_info[:2] != expected_python:
        raise ValueError(
            f"Phase 0C requires Python {manifest['dependency_lock']['python_version']}"
        )
    lock_path = repo_root / manifest["dependency_lock"]["path"]
    lock_digest = hashlib.sha256(lock_path.read_bytes()).hexdigest()
    if lock_digest != manifest["dependency_lock"]["sha256"]:
        raise ValueError("compiled dependency lock digest mismatch")
    graph = load_json(namespace / manifest["preflight_fixture_graph"]["path"])
    validate_document(graph, namespace / "preflight-fixture-graph.schema.json")
    gate = evaluate_graph(graph)
    if gate["decision"] != "accepted":
        raise ValueError(f"preflight fixture graph rejected: {gate['failed_predicates']}")
    if gate["graph_sha256"] != manifest["preflight_fixture_graph"]["sha256"]:
        raise ValueError("preflight fixture graph digest mismatch")
    gate_manifest = manifest["preflight_fixture_gate_report"]
    if gate["gate_sha256"] != gate_manifest["sha256"]:
        raise ValueError("preflight fixture gate report digest mismatch")
    retained_gate = load_json(namespace / gate_manifest["path"])
    validate_document(
        retained_gate, namespace / "preflight-fixture-gate-report.schema.json"
    )
    if canonical_bytes(retained_gate) != canonical_bytes(gate):
        raise ValueError("preflight fixture gate differs from deterministic output")
    treatments = load_json(namespace / manifest["preflight_fixture_treatments_path"])
    validate_document(
        treatments, namespace / "preflight-fixture-treatments.schema.json"
    )
    validate_treatment_pair(treatments["C"], treatments["D"])
    if treatments["C"]["preflight_fixture_graph_sha256"] != gate["graph_sha256"]:
        raise ValueError("preflight treatment fixture graph digest mismatch")
    if treatments["C"]["preflight_fixture_gate_sha256"] != gate["gate_sha256"]:
        raise ValueError("preflight treatment fixture gate digest mismatch")
    prompt_path = namespace / manifest["preflight_fixture_prompt"]["path"]
    prompt_digest = hashlib.sha256(prompt_path.read_bytes()).hexdigest()
    if prompt_digest != manifest["preflight_fixture_prompt"]["sha256"]:
        raise ValueError("preflight fixture prompt digest mismatch")
    if treatments["C"]["preflight_fixture_prompt_sha256"] != prompt_digest:
        raise ValueError("preflight treatment fixture prompt digest mismatch")
    fixture_entry = manifest["canonical_event_fixture"]
    fixture_path = namespace / fixture_entry["path"]
    if hashlib.sha256(fixture_path.read_bytes()).hexdigest() != fixture_entry["sha256"]:
        raise ValueError("canonical event fixture digest mismatch")
    fixture = load_json(fixture_path)
    validate_document(fixture, namespace / "canonical-event-fixture.schema.json")
    normalized, _ = normalize_ledger(fixture["events"])
    for event in normalized:
        validate_document(event, namespace / "event.schema.json")
    return manifest, gate


def available_port() -> int:
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


async def a2a_round_trip(base_url: str, events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    import httpx
    from a2a.client import A2ACardResolver, ClientConfig, create_client
    from a2a.helpers import new_data_message
    from a2a.types import Role, SendMessageRequest
    from google.protobuf import json_format

    async with httpx.AsyncClient(timeout=5.0) as http_client:
        resolver = A2ACardResolver(http_client, base_url)
        card = await resolver.get_agent_card()
        if not any(
            interface.protocol_binding == "JSONRPC"
            and interface.protocol_version == PROTOCOL_VERSION
            for interface in card.supported_interfaces
        ):
            raise ValueError("discovered card lacks A2A v1.0 JSON-RPC interface")
        client = await create_client(
            card,
            ClientConfig(
                streaming=False,
                httpx_client=http_client,
                supported_protocol_bindings=["JSONRPC"],
            ),
        )
        echoed: list[dict[str, Any]] = []
        for event in events:
            request = SendMessageRequest(
                message=new_data_message(
                    event, media_type="application/json", role=Role.ROLE_USER
                )
            )
            responses = [response async for response in client.send_message(request)]
            if len(responses) != 1 or responses[0].WhichOneof("payload") != "message":
                raise ValueError("expected one non-streaming A2A message response")
            message = responses[0].message
            if len(message.parts) != 1 or not message.parts[0].HasField("data"):
                raise ValueError("expected one structured A2A response part")
            echoed.append(json_format.MessageToDict(message.parts[0].data))
        return echoed


async def validate_a2a_version_rejection(base_url: str) -> bool:
    import httpx
    from a2a.helpers import new_data_message
    from a2a.types import Role, SendMessageRequest
    from google.protobuf import json_format

    request = SendMessageRequest(
        message=new_data_message(
            {"probe": "version"}, media_type="application/json", role=Role.ROLE_USER
        )
    )
    body = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "SendMessage",
        "params": json_format.MessageToDict(request),
    }
    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.post(base_url, json=body)
    error = response.json().get("error", {})
    if error.get("code") != -32009:
        raise ValueError("A2A server accepted the implicit unsupported v0.3 request")
    return True


def run_a2a_server(
    runner: Path, events: list[dict[str, Any]]
) -> tuple[list[dict[str, Any]], str, bool]:
    import httpx

    port = available_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="phase-0c-a2a-") as temporary_dir:
        evidence_file = Path(temporary_dir) / "validated-version.txt"
        stderr_file = Path(temporary_dir) / "server-stderr.log"
        with stderr_file.open("w", encoding="utf-8") as stderr_stream:
            process = subprocess.Popen(
                [
                    sys.executable,
                    str(runner / "phase_0c_a2a_server.py"),
                    "--port",
                    str(port),
                    "--header-evidence-file",
                    str(evidence_file),
                ],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=stderr_stream,
                text=True,
            )

            def stderr_excerpt() -> str:
                stderr_stream.flush()
                return stderr_file.read_text(encoding="utf-8")[-2000:].strip()

            try:
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise RuntimeError(
                            "A2A server exited before discovery "
                            f"(returncode={process.returncode}): "
                            f"{stderr_excerpt() or 'no server stderr'}"
                        )
                    try:
                        response = httpx.get(
                            f"{base_url}/.well-known/agent-card.json", timeout=0.2
                        )
                        if response.status_code == 200:
                            break
                    except httpx.HTTPError:
                        pass
                    time.sleep(0.05)
                else:
                    raise TimeoutError(
                        "A2A discovery endpoint did not become ready: "
                        f"{stderr_excerpt() or 'no server stderr'}"
                    )
                version_header_validated = asyncio.run(
                    validate_a2a_version_rejection(base_url)
                )
                echoed = asyncio.run(a2a_round_trip(base_url, events))
                if not evidence_file.exists():
                    raise ValueError("client did not send A2A-Version: 1.0")
                return (
                    echoed,
                    evidence_file.read_text(encoding="utf-8"),
                    version_header_validated,
                )
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.output is None and not args.validate_only:
        parser.error("--output is required unless --validate-only is used")
    manifest_path = args.manifest.resolve()
    manifest, gate = validate_apparatus(manifest_path)
    if args.validate_only:
        print("Phase 0C apparatus validates; paid execution remains blocked")
        return 0
    if importlib.metadata.version("a2a-sdk") != SDK_VERSION:
        raise ValueError(f"a2a-sdk must be exactly {SDK_VERSION}")

    namespace = manifest_path.parent
    fixture_path = namespace / manifest["canonical_event_fixture"]["path"]
    fixture = load_json(fixture_path)
    fixture_ledger, fixture_suppressed = CanonicalFixtureAdapter(fixture_path).receive()
    a2a_events, validated_version_header, version_header_validated = run_a2a_server(
        Path(__file__).parent, fixture["events"]
    )
    a2a_ledger, a2a_suppressed = normalize_ledger(a2a_events)
    if canonical_bytes(fixture_ledger) != canonical_bytes(a2a_ledger):
        raise ValueError("canonical fixture and A2A echo payloads differ")
    validate_document(
        {"schema_version": "task-parallelism-phase-0c-ledger.v1", "events": fixture_ledger},
        namespace / "ledger.schema.json",
    )
    report = {
        "schema_version": "task-parallelism-phase-0c-preflight.v1",
        "status": "pass",
        "campaign": manifest["campaign_id"],
        "candidate_processes_started": 0,
        "paid_execution": "blocked-pending-explicit-approval",
        "preflight_fixture_graph_decision": gate["decision"],
        "preflight_fixture_graph_sha256": gate["graph_sha256"],
        "preflight_fixture_gate_sha256": gate["gate_sha256"],
        "preflight_fixture_execution_waves": gate["execution_waves"],
        "all_seven_issue_predicates_passed": all(
            item["passed"] for item in gate["predicate_results"]
        ),
        "a2a": {
            "protocol_version": PROTOCOL_VERSION,
            "specification_release": SPECIFICATION_RELEASE,
            "sdk_version": SDK_VERSION,
            "loopback_only": True,
            "separate_server_process": True,
            "discovery_path": "/.well-known/agent-card.json",
            "discovery_succeeded": True,
            "version_header_validated": version_header_validated,
            "validated_version_header": validated_version_header,
            "structured_non_streaming_round_trip": True,
        },
        "canonical_fixture_adapter": {
            "fixture_backed": True,
            "transport_calls": 0,
        },
        "canonical_payload_echo_equivalent": True,
        "duplicate_events_suppressed": require_equal_suppressed(
            fixture_suppressed, a2a_suppressed
        ),
        "canonical_ledger": fixture_ledger,
        "future_paid_topology_limit": manifest["future_paid_topology_limit"],
    }
    validate_document(report, namespace / "preflight.schema.json")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(canonical_bytes(report))
    print("Phase 0C no-spend preflight passed; paid execution remains blocked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
