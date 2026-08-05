#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism"
}

@test "Phase 0C gate accepts, rejects without launch, sequences dependencies, and is deterministic" {
  run python3 - "${RUNNER}" <<'PY'
import copy
import json
import sys

sys.path.insert(0, sys.argv[1])
from phase_0c_gate import evaluate_graph, simulate_schedule

graph = {
    "schema_version": "task-parallelism-phase-0c-graph.v1",
    "graph_id": "vector-siege-transport-v1",
    "concurrency_cap": 2,
    "shared_contracts": [
        {"id": "game-state", "owner": "parent", "frozen": True},
    ],
    "integration_validation": ["npm test", "npm run build", "stage-1-playwright"],
    "nodes": [
        {
            "id": "engine",
            "outcome": "Player can complete one deterministic combat round.",
            "independently_testable": True,
            "depends_on": [],
            "dependency_closure": [],
            "required_contracts": ["game-state"],
            "predicted_writes": ["src/engine.ts"],
            "child_validation": ["npm test -- engine"],
            "substantive_work": {"estimated_minutes": 20, "justification": "Combat state and collision behavior."},
        },
        {
            "id": "interface",
            "outcome": "Player can see and control the combat round.",
            "independently_testable": True,
            "depends_on": ["engine"],
            "dependency_closure": ["engine"],
            "required_contracts": ["game-state"],
            "predicted_writes": ["src/engine.ts", "src/main.ts"],
            "child_validation": ["npm test -- interface"],
            "substantive_work": {"estimated_minutes": 20, "justification": "Controls, HUD, and visual feedback."},
        },
    ],
}

accepted = evaluate_graph(graph)
assert accepted["decision"] == "accepted", accepted
assert accepted["execution_waves"] == [["engine"], ["interface"]], accepted
assert json.dumps(accepted, sort_keys=True, separators=(",", ":")) == json.dumps(
    evaluate_graph(copy.deepcopy(graph)), sort_keys=True, separators=(",", ":")
)

active = set()
completed = set()
launches = []

def callback(node):
    assert set(node["depends_on"]) <= completed
    active.add(node["id"])
    launches.append(node["id"])
    active.remove(node["id"])
    completed.add(node["id"])

simulate_schedule(graph, callback)
assert launches == ["engine", "interface"]

predicate_mutations = [
    ("independently-testable-outcomes", lambda value: value["nodes"][0].update(independently_testable=False)),
    ("dependency-closure", lambda value: value["nodes"][1].update(dependency_closure=[])),
    ("parent-owned-frozen-contracts", lambda value: value["shared_contracts"][0].update(frozen=False)),
    ("write-sets-or-sequencing", lambda value: value["nodes"][1].update(depends_on=[], dependency_closure=[])),
    ("child-and-integration-validation", lambda value: value["nodes"][0].update(child_validation=[])),
    ("child-and-integration-validation", lambda value: value.update(integration_validation=[])),
    ("substantive-work", lambda value: value["nodes"][0].update(substantive_work={"estimated_minutes": 2, "justification": "tiny"})),
    ("concurrency-cap", lambda value: value.update(concurrency_cap=3)),
]
for predicate, mutate in predicate_mutations:
    rejected_graph = copy.deepcopy(graph)
    mutate(rejected_graph)
    rejected = evaluate_graph(rejected_graph)
    assert rejected["decision"] == "rejected", (predicate, rejected)
    assert predicate in rejected["failed_predicates"], (predicate, rejected)
    child_launches = []
    simulate_schedule(rejected_graph, lambda node: child_launches.append(node["id"]))
    assert child_launches == [], (predicate, child_launches)

prefix_overlap = copy.deepcopy(graph)
prefix_overlap["nodes"][1].update(depends_on=[], dependency_closure=[])
prefix_overlap["nodes"][1]["predicted_writes"] = ["src"]
assert evaluate_graph(prefix_overlap)["decision"] == "rejected"
assert "write-sets-or-sequencing" in evaluate_graph(prefix_overlap)["failed_predicates"]

for unsafe_path in ["../outside.py", "/tmp/outside.py", "src/*.py", ".", ""]:
    unsafe = copy.deepcopy(graph)
    unsafe["nodes"][0]["predicted_writes"] = [unsafe_path]
    assert "write-sets-or-sequencing" in evaluate_graph(unsafe)["failed_predicates"]

for broken_dependencies in [
    {"engine": ["interface"], "interface": ["engine"]},
    {"engine": ["missing"], "interface": ["engine"]},
]:
    broken = copy.deepcopy(graph)
    for node in broken["nodes"]:
        node["depends_on"] = broken_dependencies[node["id"]]
    assert "dependency-closure" in evaluate_graph(broken)["failed_predicates"]

transitive = copy.deepcopy(graph)
transitive["nodes"][1]["predicted_writes"] = ["src/interface.ts"]
transitive["nodes"].append(
    {
        "id": "integration",
        "outcome": "Player can finish the integrated journey.",
        "independently_testable": True,
        "depends_on": ["interface"],
        "dependency_closure": ["engine", "interface"],
        "required_contracts": ["game-state"],
        "predicted_writes": ["src/integration.ts"],
        "child_validation": ["npm test -- integration"],
        "substantive_work": {"estimated_minutes": 20, "justification": "Integrated player journey."},
    }
)
transitive_report = evaluate_graph(transitive)
assert transitive_report["decision"] == "accepted", transitive_report
assert transitive_report["execution_waves"] == [["engine"], ["interface"], ["integration"]]

print("phase-0c graph gate contract passed")
PY
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'phase-0c graph gate contract passed'* ]]
}
