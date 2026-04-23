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
├── research/           # Analyst output (analysis artifacts)
│   └── *.md            # Needs analysis, competitive landscape, impact scores
├── guides/             # How-to guides for developers
│   └── *.md            # Setup, deployment, contribution guides
├── decisions/          # Architecture Decision Records (ADRs)
│   └── adr-*.md        # Decision records
└── postmortems/        # Retrospective lessons learned
    └── postmortem-*.md # Postmortem records (see postmortems/README.md)
```

## What Belongs Here

### `reference/`
- Original project specifications
- Research notes
- External API documentation
- Competitor analysis
- Historical context

### `research/`
- Analyst output (needs analysis, competitive landscape, impact scores)
- Problem validation artifacts
- Stakeholder feedback summaries
- Market research findings

### `guides/`
- Development setup instructions
- Deployment procedures
- Troubleshooting guides
- Contribution guidelines

### `decisions/`
- Architecture Decision Records (ADRs)
- Design rationale
- Trade-off analysis

### `postmortems/`
- Retrospective lessons learned (incidents, surprises, friction)
- Paired with ADRs: ADRs are prospective, postmortems are retrospective
- See `postmortems/README.md` for the "What generalizes" promotion gate

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
- [ADR-004: Analyst Role and Feedback Loop](decisions/adr-004-analyst-role-and-feedback-loop.md) - Adding pre-Architect validation and iterative feedback
- [ADR Template](decisions/adr-template.md) - Template for new architecture decisions

### Postmortems / Lessons Learned
- [Postmortems Index](postmortems/README.md) - When to write a postmortem; ADR-vs-postmortem split; "What generalizes" promotion gate
- [Postmortem Template](postmortems/postmortem-template.md) - Template for retrospective lessons

### Reference
- Add specification documents as needed
