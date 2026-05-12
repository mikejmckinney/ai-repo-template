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
├── state/               # Live coordination = GitHub (ADR-025); this dir holds the comment template + legacy mirrors
│   ├── README.md        # How task state works post-ADR-025
│   ├── _active.md       # Legacy: pre-ADR-025 multi-task working board
│   ├── coordination.md  # Legacy: pre-ADR-025 live claim board
│   ├── agent_state_comment_template.md # Canonical `agent-state:v1` comment template (ADR-025)
│   └── task_<id>.md     # Legacy: pre-ADR-025 per-task progress files
└── vision/              # Design artifacts (mockups, diagrams)
    ├── mockups/         # UI/UX mockups and wireframes
    └── architecture/    # System architecture diagrams (use Mermaid.js)
```

## Quick Start for Agents (Lazy Load Pattern)

1. Read this file first (The Map)
2. Read the assigned GitHub issue body, the linked PR body if any, and the latest `agent-state:v1` issue/PR comment — the live coordination baton per ADR-025
3. Read `rules/agent_ownership.md` to know which files your role may touch
4. (Legacy / transitional) Skim `state/coordination.md` and `state/_active.md` for in-flight pre-ADR-025 locks (advisory only)
5. Read `sessions/latest_summary.md` for durable retrospective lessons from recent merged PRs
6. Read `roadmap.md` to understand project phases (The Plan)
7. Reference `rules/` ONLY when making changes to those domains. `rules/domain_code_quality.md` is the built-in SOLID/TDD/clean-code floor — read it before any non-trivial refactor.
8. Reference `vision/` for design guidance

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
