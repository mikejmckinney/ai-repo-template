# ADR-032: Monolithic agent and review lifecycle

## Status

Accepted

## Date

2026-07-14

## Context

ADR-031 records that the benchmarked multi-role pipelines had no favorable ROI crossover against strong monolithic runs. The repository nevertheless continued to register ten roles on four platforms and maintained separate formal-review, resolution, finalization, and consensus-planning surfaces. Those unused surfaces created drift and maintenance cost.

## Decision

- Routine implementation uses one monolithic agent.
- CI and lint are the blocking pre-merge controls.
- Advisory review is optional via `ai-review:live`, runs in parallel with active implementation, updates one sticky comment, and cannot mutate or block the PR.
- Daily post-merge retro and weekly full-repository review remain the recurring review and draft-fix pipelines.
- `.opencode/skills/local-consensus/` is the sole opt-in multi-model mechanism.
- One compact shared review-lens contract feeds advisory, daily, and weekly prompts.
- Canonical roles, platform overlays, native reviewer rules, multi-role dispatch, formal AI review, review resolution, finalization, and legacy consensus planning are retired.
- Monolithic assignment, cross-PR overlap visibility, and auto-rebase safety remain.

This ADR supersedes ADR-003, ADR-004, ADR-005, ADR-007, ADR-008, ADR-009, ADR-014, ADR-019, ADR-023, and ADR-024 for active operations. Their bodies and benchmark artifacts remain historical evidence.

## Consequences

The live operating model has fewer registries, labels, workflows, and synchronization checks. Advisory feedback may finish after implementation advances, by design. Some defects will be found post-merge by retro rather than by formal pre-merge AI review; deterministic CI remains blocking.

## References

- Issue #474
- ADR-030
- ADR-031
