<!-- TEMPLATE_PLACEHOLDER: Update for your project's documentation -->

# Documentation Directory

> **Purpose**: Human-readable reference documentation, specifications, and research materials.

## Priority Note for AI Agents

This directory contains **supporting documentation**. When sources conflict,
see `AGENTS.md` §"Truth hierarchy" for the canonical order (summary:
`.context/**` > `docs/**` > codebase).

## Directory Structure

```
docs/
├── README.md           # This file
├── reference/          # Historical specs, research, external references
│   └── *.md            # Specification documents
├── guides/             # How-to guides for developers
│   └── *.md            # Setup, deployment, contribution guides
└── decisions/          # Architecture Decision Records (ADRs)
    └── adr-*.md        # Decision records
```

## What Belongs Here

### `reference/`
- Original project specifications
- Research notes
- External API documentation
- Competitor analysis
- Historical context

### `guides/`
- Development setup instructions
- Deployment procedures
- Troubleshooting guides
- Contribution guidelines

### `decisions/`
- Architecture Decision Records (ADRs)
- Design rationale
- Trade-off analysis

## What Does NOT Belong Here

- Current project state → use `.context/state/`
- Project roadmap → use `.context/roadmap.md`
- Domain rules/constraints → use `.context/rules/`
- Design mockups → use `.context/vision/`

## Creating an ADR

Use this template for architecture decisions:

```markdown
# ADR-NNN: Title

## Status
Proposed | Accepted | Deprecated | Superseded by ADR-XXX

## Context
What is the issue we're facing?

## Decision
What have we decided to do?

## Consequences
What are the positive and negative consequences?
```

## Current Documentation

### Guides
- [Context Files Explained](guides/context-files-explained.md) - **Start here**: Understanding all the documentation files
- [Agent Best Practices](guides/agent-best-practices.md) - Token limits, state conflicts, secrets, session handoff

### Decisions (ADRs)
- [ADR-001: Context Pack Structure](decisions/adr-001-context-pack-structure.md) - Why we use `.context/` for LLM memory
- [ADR Template](decisions/adr-template.md) - Template for new architecture decisions

### Reference
- Add specification documents as needed
