#!/usr/bin/env python3
"""Pure deterministic graph gate for the Phase 0C transport experiment."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Callable
from pathlib import PurePosixPath
from typing import Any


MIN_SUBSTANTIVE_MINUTES = 15
PREDICATES = (
    "independently-testable-outcomes",
    "dependency-closure",
    "parent-owned-frozen-contracts",
    "write-sets-or-sequencing",
    "child-and-integration-validation",
    "substantive-work",
    "concurrency-cap",
)


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _normalized_write_path(raw_path: Any) -> PurePosixPath | None:
    if not isinstance(raw_path, str) or not raw_path or raw_path == ".":
        return None
    if raw_path.startswith("/") or "\\" in raw_path or any(
        marker in raw_path for marker in ("*", "?", "[")
    ):
        return None
    path = PurePosixPath(raw_path)
    if ".." in path.parts or path.as_posix() != raw_path:
        return None
    return path


def _paths_overlap(left: PurePosixPath, right: PurePosixPath) -> bool:
    return left == right or left in right.parents or right in left.parents


def _dependency_closure(node_id: str, dependencies: dict[str, list[str]]) -> set[str]:
    closure: set[str] = set()
    visiting: set[str] = set()

    def visit(current: str) -> None:
        if current in visiting:
            raise ValueError("dependency cycle")
        visiting.add(current)
        for dependency in dependencies.get(current, []):
            if dependency not in dependencies:
                raise ValueError("unknown dependency")
            closure.add(dependency)
            visit(dependency)
        visiting.remove(current)

    visit(node_id)
    return closure


def _execution_waves(
    node_ids: list[str], closures: dict[str, set[str]], concurrency_cap: int
) -> list[list[str]]:
    remaining = set(node_ids)
    completed: set[str] = set()
    waves: list[list[str]] = []
    while remaining:
        wave = sorted(node for node in remaining if closures[node] <= completed)
        if not wave:
            return []
        bounded_wave = wave[:concurrency_cap]
        waves.append(bounded_wave)
        completed.update(bounded_wave)
        remaining.difference_update(bounded_wave)
    return waves


def evaluate_graph(graph: dict[str, Any]) -> dict[str, Any]:
    """Return a timestamp-free, byte-stable decision for all graph predicates."""
    nodes = graph.get("nodes", [])
    node_ids = [node.get("id") for node in nodes]
    unique_ids = len(node_ids) == len(set(node_ids)) and all(node_ids)
    dependencies = {
        node["id"]: node.get("depends_on", []) for node in nodes if node.get("id")
    }
    closures: dict[str, set[str]] = {}
    closure_valid = bool(nodes) and bool(unique_ids)
    if closure_valid:
        try:
            closures = {
                node_id: _dependency_closure(node_id, dependencies)
                for node_id in sorted(dependencies)
            }
        except ValueError:
            closure_valid = False
    if closure_valid:
        closure_valid = all(
            sorted(node.get("dependency_closure", []))
            == sorted(closures[node["id"]])
            for node in nodes
        )

    contracts = graph.get("shared_contracts", [])
    contract_ids = {contract.get("id") for contract in contracts}
    contracts_valid = bool(contracts) and all(
        contract.get("id")
        and contract.get("owner") == "parent"
        and contract.get("frozen") is True
        for contract in contracts
    )
    contracts_valid = contracts_valid and all(
        bool(node.get("required_contracts"))
        and set(node.get("required_contracts", [])) <= contract_ids
        for node in nodes
    )

    normalized_writes: dict[str, list[PurePosixPath]] = {}
    writes_valid = closure_valid
    if writes_valid:
        for node in nodes:
            paths = [_normalized_write_path(path) for path in node.get("predicted_writes", [])]
            if not paths or any(path is None for path in paths):
                writes_valid = False
                break
            normalized_writes[node["id"]] = [path for path in paths if path is not None]
    if writes_valid:
        for index, left in enumerate(nodes):
            for right in nodes[index + 1 :]:
                overlap = any(
                    _paths_overlap(left_path, right_path)
                    for left_path in normalized_writes[left["id"]]
                    for right_path in normalized_writes[right["id"]]
                )
                sequenced = (
                    left["id"] in closures[right["id"]]
                    or right["id"] in closures[left["id"]]
                )
                if overlap and not sequenced:
                    writes_valid = False

    checks = {
        "independently-testable-outcomes": bool(nodes)
        and all(
            node.get("independently_testable") is True
            and bool(str(node.get("outcome", "")).strip())
            for node in nodes
        ),
        "dependency-closure": closure_valid,
        "parent-owned-frozen-contracts": contracts_valid,
        "write-sets-or-sequencing": writes_valid,
        "child-and-integration-validation": bool(nodes)
        and all(bool(node.get("child_validation")) for node in nodes)
        and bool(graph.get("integration_validation")),
        "substantive-work": bool(nodes)
        and all(
            node.get("substantive_work", {}).get("estimated_minutes", 0)
            >= MIN_SUBSTANTIVE_MINUTES
            and bool(
                str(
                    node.get("substantive_work", {}).get("justification", "")
                ).strip()
            )
            for node in nodes
        ),
        "concurrency-cap": graph.get("concurrency_cap") == 2,
    }
    failed = [predicate for predicate in PREDICATES if not checks[predicate]]
    waves = _execution_waves(node_ids, closures, graph["concurrency_cap"]) if not failed else []
    report = {
        "schema_version": "task-parallelism-phase-0c-preflight-fixture-gate-report.v1",
        "graph_id": graph.get("graph_id"),
        "graph_sha256": sha256(graph),
        "decision": "rejected" if failed else "accepted",
        "predicate_results": [
            {"predicate": predicate, "passed": checks[predicate]}
            for predicate in PREDICATES
        ],
        "failed_predicates": failed,
        "execution_waves": waves,
        "candidate_processes_started": 0,
    }
    report["gate_sha256"] = sha256(report)
    return report


def simulate_schedule(
    graph: dict[str, Any], callback: Callable[[dict[str, Any]], None]
) -> None:
    """Exercise the pre-child boundary without creating processes."""
    report = evaluate_graph(graph)
    if report["decision"] != "accepted":
        return
    by_id = {node["id"]: node for node in graph["nodes"]}
    for wave in report["execution_waves"]:
        for node_id in wave:
            callback(by_id[node_id])
