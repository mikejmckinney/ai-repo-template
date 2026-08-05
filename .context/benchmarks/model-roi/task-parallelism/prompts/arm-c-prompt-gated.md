# Arm C: Prompt-Gated Autonomous Fan-Out

This directional treatment replaces the deferred deterministic external gate.
Before implementation, create and self-check a work graph that identifies:

- independently testable child outcomes;
- dependencies and parent-owned shared contracts;
- predicted write sets with no unresolved overlap;
- child validation and parent integration validation; and
- a concurrency level justified by enough independent work.

Use native subagents for the packages that pass that self-check. Keep shared
contracts and final integration under the parent. If a package is coupled or its
write set overlaps another package, sequence it or keep it with the parent rather
than dispatching it. Complete the implementation, integration, and user-outcome
validation autonomously in this checkout.
