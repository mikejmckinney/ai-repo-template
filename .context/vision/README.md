# Vision & Design Artifacts

> **Purpose**: Keep the template repo's design and workflow diagrams in one place, and give downstream repos a concrete example of a populated `vision/` tree.

## What Belongs Here

- `architecture/` holds the Mermaid diagrams that explain how the template works.
- `mockups/` is reserved for downstream product repos or future UI-heavy template work.

This repo is a process/template project, not a product UI, so its most useful vision artifacts are architecture and state-flow diagrams rather than visual mockups.

## Current Artifacts

- [architecture/multi-agent-flow.md](architecture/multi-agent-flow.md) - the current Parent Orchestrator -> Analyst -> Architect -> plan-gate (Critic notes + Judge approval) -> PM -> implementers -> QA -> Critic -> Judge workflow.
- [architecture/state-surfaces.md](architecture/state-surfaces.md) - the ADR-025 live-state hierarchy plus the repo-local reference surfaces that remain.

## How to Use These Files

1. Start with `architecture/multi-agent-flow.md` when you need the control flow for planning, dispatch, or review.
2. Read `architecture/state-surfaces.md` when touching live-state, session-summary, or onboarding reset behavior.
3. Keep these diagrams aligned with `.context/roadmap.md`, `.context/state/README.md`, and `docs/guides/multi-agent-coordination.md`.

## Related References

- [../00_INDEX.md](../00_INDEX.md)
- [../roadmap.md](../roadmap.md)
- [../state/README.md](../state/README.md)
- [../../docs/guides/multi-agent-coordination.md](../../docs/guides/multi-agent-coordination.md)
