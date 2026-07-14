# Vision & Design Artifacts

> **Purpose**: Keep the template repo's design and workflow diagrams in one place, and give downstream repos a concrete example of a populated `vision/` tree.

## What Belongs Here

- `architecture/` holds the Mermaid diagrams that explain how the template works.
- `mockups/` is reserved for downstream product repos or future UI-heavy template work.

This repo is a process/template project, not a product UI, so its most useful vision artifacts are architecture and state-flow diagrams rather than visual mockups.

## Current Artifacts

- [architecture/state-surfaces.md](architecture/state-surfaces.md) - the ADR-025 live-state hierarchy plus the repo-local reference surfaces that remain.

## How to Use These Files

1. Start with ADR-031 and `docs/guides/agent-pipeline.md` for execution and review flow.
2. Read `architecture/state-surfaces.md` when touching live-state, session-summary, or onboarding reset behavior.
3. Keep these diagrams aligned with `.context/roadmap.md` and `.context/state/README.md`.

## Related References

- [../00_INDEX.md](../00_INDEX.md)
- [../roadmap.md](../roadmap.md)
- [../state/README.md](../state/README.md)
- [../../docs/guides/agent-pipeline.md](../../docs/guides/agent-pipeline.md)
