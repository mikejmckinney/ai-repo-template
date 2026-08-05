#!/usr/bin/env python3
"""Causal-freeze validation for matched Phase 0C treatments."""

from __future__ import annotations

from typing import Any

from phase_0c_gate import canonical_bytes


class CausalFreezeError(ValueError):
    """Raised when treatment configuration drifts outside transport evidence."""


def validate_treatment_pair(c_arm: dict[str, Any], d_arm: dict[str, Any]) -> None:
    c_common = {key: value for key, value in c_arm.items() if key != "transport"}
    d_common = {key: value for key, value in d_arm.items() if key != "transport"}
    if canonical_bytes(c_common) != canonical_bytes(d_common):
        raise CausalFreezeError("treatments differ outside transport")
    c_transport = c_arm.get("transport", {})
    d_transport = d_arm.get("transport", {})
    if set(c_transport) != {"backend", "backend_evidence"} or set(d_transport) != {
        "backend",
        "backend_evidence",
    }:
        raise CausalFreezeError("transport may contain only backend and backend_evidence")
    if c_transport["backend"] == d_transport["backend"]:
        raise CausalFreezeError("transport backends must differ")
