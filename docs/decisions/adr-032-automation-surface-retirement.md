# ADR-032: Retire unused automation and isolate benchmark apparatus

## Status

Accepted

## Date

2026-07-15

## Context

The template retained a Copilot assignment queue, automatic rebasing, generic
deployment workflows, and deployment templates after those surfaces stopped
serving active repositories. Their event triggers and setup contracts imposed
maintenance and Actions cost even when no user opted in. Model-ROI benchmark
apparatus also lived on `main` despite being an occasional evaluation lab rather
than part of the reusable template.

## Decision

Remove the unused assignment, rebase, keep-warm, and connection-validation
automation together with their active setup and documentation contracts. Keep
existing GitHub labels as historical metadata, but stop provisioning retired
labels and budget variables. Branch owners update their own branches; the
parallelism report remains advisory.

Keep benchmark conclusions and this repository's execution policy on `main`.
Keep model-ROI harnesses, tasks, graders, raw evidence, and benchmark-only checks
on `benchmark/roi`, synchronized from `main` only when a benchmark campaign runs.
Published results must identify pinned commits or tags rather than relying on the
mutable branch head.

This ADR supersedes ADR-010 and the queue-drain portion of ADR-006. It narrows
ADR-031's active lifecycle without changing its evidence-backed monolithic-agent,
blocking-CI, advisory-review, or recurring-review decisions.

## Options Considered

### Keep dormant surfaces

Rejected because unused event wiring and setup contracts still incur maintenance
cost and obscure the supported product.

### Disable but retain workflows

Rejected because manual-only placeholders still appear supported and continue to
require tests and documentation.

### Move only raw benchmark artifacts

Rejected because benchmark harnesses and checks are also evaluation-lab concerns,
not runtime requirements for template consumers.

## Consequences

### Positive

- `main` describes the maintained template product more accurately.
- Normal CI no longer validates occasional benchmark apparatus.
- Workflow runs and setup options no longer advertise unused capabilities.

### Negative

- Operators who used retired workflows must retain them in derived repositories.
- Benchmark campaigns must update `benchmark/roi` before execution.

### Neutral

- Historical ADRs, labels, benchmark results, and Git history remain available.
- Production behavior promoted from prior benchmarks remains on `main` with its
  behavioral tests.

## Implementation

- [x] Remove retired workflows, setup surfaces, tests, and active documentation.
- [x] Consolidate verification around observable contracts.
- [x] Move model-ROI apparatus and benchmark-only checks off `main`.
- [x] Preserve canonical result records and production retro behavior.

## References

- Issue [#483](https://github.com/mikejmckinney/ai-repo-template/issues/483)
- [ADR-006](./adr-006-auto-merge-opt-in-model.md)
- [ADR-010](./adr-010-auto-rebase-on-merge.md)
- [ADR-016](./adr-016-pre-merge-verification-gate.md)
- [ADR-031](./adr-031-agent-model-roi-benchmark-policy.md)
