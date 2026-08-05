#!/usr/bin/env python3
"""Canonical event normalization and fixture-backed GitHub transport."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

from phase_0c_gate import canonical_bytes, sha256


EVENT_KINDS = (
    "task-assigned",
    "task-status",
    "artifact-published",
    "task-reclassified",
    "task-failed",
)
MAX_EVENTS = 64
MAX_PAYLOAD_BYTES = 16_384


class CanonicalEventError(ValueError):
    """Raised for malformed or conflicting canonical events."""


def normalize_ledger(events: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], int]:
    if len(events) > MAX_EVENTS:
        raise CanonicalEventError("event count exceeds bound")
    retained: dict[str, dict[str, Any]] = {}
    suppressed = 0
    for raw in events:
        event = copy.deepcopy(raw)
        event_id = event.get("event_id", "")
        if not isinstance(event_id, str) or not event_id or len(event_id) > 64:
            raise CanonicalEventError("invalid event_id")
        if event.get("kind") not in EVENT_KINDS:
            raise CanonicalEventError("invalid event kind")
        sequence = event.get("sequence")
        if not isinstance(sequence, (int, float)) or int(sequence) != sequence or sequence < 1:
            raise CanonicalEventError("invalid event sequence")
        event["sequence"] = int(sequence)
        payload = event.get("payload")
        if not isinstance(payload, dict) or len(canonical_bytes(payload)) > MAX_PAYLOAD_BYTES:
            raise CanonicalEventError("invalid event payload")
        event["schema_version"] = "task-parallelism-phase-0c-event.v1"
        event["payload_sha256"] = sha256(payload)
        if event_id in retained:
            if canonical_bytes(retained[event_id]) != canonical_bytes(event):
                raise CanonicalEventError("duplicate event_id has changed content")
            suppressed += 1
            continue
        retained[event_id] = event
    ledger = sorted(retained.values(), key=lambda event: (event["sequence"], event["event_id"]))
    sequences = [event["sequence"] for event in ledger]
    if sequences != list(range(1, len(ledger) + 1)):
        raise CanonicalEventError("event sequence must be contiguous")
    return ledger, suppressed


class CanonicalFixtureAdapter:
    """Read committed canonical fixture events without transport behavior."""

    def __init__(self, fixture_path: Path):
        self.fixture_path = fixture_path

    def receive(self) -> tuple[list[dict[str, Any]], int]:
        fixture = json.loads(self.fixture_path.read_text(encoding="utf-8"))
        return normalize_ledger(fixture["events"])
