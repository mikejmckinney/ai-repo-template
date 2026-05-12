<!-- TEMPLATE_PLACEHOLDER: Replace with actual project context index -->

# Context Pack Index

> **Purpose**: This is the entry point for AI agents to understand the project's direction, constraints, and current state.

## How to Use This Directory

The `.context/` directory contains **canonical project truth**.

### Priority Order (when conflicts arise)

See `AGENTS.md` §"Truth hierarchy" for the canonical definition. Summary:
`.context/**` > `docs/**` > codebase.

## Directory Structure

```
.context/
├── 00_INDEX.md          # This file - start here (The Map)
├── backlog.yaml         # Machine-readable task list dispatched into issues
├── backlog.schema.json  # JSON Schema for backlog.yaml
├── roadmap.md           # Phase-by-phase plan with acceptance criteria (The Plan)
├── rules/               # Immutable constraints and domain rules
│   ├── agent_ownership.md    # Canonical role → owned paths map (read before editing)
│   ├── domain_code_quality.md # Built-in language-neutral SOLID/TDD/clean-code floor
│   └── domain_*.md           # Add your own stack-specific rules (e.g., domain_auth.md)
├── sessions/            # Session history to prevent repeating mistakes
│   └── latest_summary.md # Most recent session summary
├── state/               # Live coordination + legacy task tracking
│   ├── README.md        # How to use the live-state surfaces
│   ├── agent_state_comment_template.md  # ADR-025 GitHub issue/PR comment template (primary live-state surface for new work)
│   ├── _active.md       # Legacy multi-task file (ADR-018; compat view per ADR-025)
│   └── coordination.md  # Legacy lock board (compat view per ADR-025)
└── vision/              # Design artifacts (mockups, diagrams)
    ├── mockups/         # UI/UX mockups and wireframes
    └── architecture/    # System architecture diagrams (use Mermaid.js)
```

## Quick Start for Agents (Lazy Load Pattern)

1. Read this file first (The Map)
2. Read the assigned GitHub issue + linked PR + latest `agent-state:v1` comment + current `agent:*` labels for your work item (per ADR-025); on legacy branches, also check `state/coordination.md` for live locks
3. Read `rules/agent_ownership.md` to know which files your role may touch
4. Read `sessions/latest_summary.md` for durable lessons from recent sessions
5. Read `roadmap.md` to understand project phases and priority order (The Plan)
6. Reference `rules/` ONLY when making changes to those domains. `rules/domain_code_quality.md` is the built-in SOLID/TDD/clean-code floor — read it before any non-trivial refactor.
7. Reference `vision/` for design guidance

**Note:** Don't read everything at once. This index tells you what exists; load files on-demand to save tokens.

**Multi-agent workflow**: See `docs/guides/multi-agent-coordination.md` for how role-specialized agents (Architect, Frontend, Backend, PM, QA, DevOps, Docs, Judge) coordinate in parallel without conflicts.

**For full documentation on file purposes**, see `docs/guides/context-files-explained.md`.

## Project Summary

<!-- Replace this section with actual project summary -->

**Project Name**: [TBD]  
**Description**: [TBD]  
**Current Phase**: [TBD]  
**Tech Stack**: [TBD]

## Key Decisions Log

| Date | Decision | Rationale | Files Affected |
|------|----------|-----------|----------------|
| YYYY-MM-DD | Example decision | Why it was made | `path/to/file` |

## Next Steps

- [ ] Replace this placeholder with actual project context
- [ ] Define roadmap phases
- [ ] Add domain rules
- [ ] Add initial design mockups if available
