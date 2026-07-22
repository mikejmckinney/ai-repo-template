# Documentation Directory

> **Purpose**: Human-readable reference documentation, specifications, and research materials.

## Priority Note for AI Agents

This directory contains **supporting documentation**. When sources conflict,
see `AGENTS.md` §"Truth hierarchy" for the canonical order (summary: current
issue/PR > `AGENTS.md` > `.context/**` > `docs/**` > codebase).

## Directory Structure

```text
docs/
├── README.md           # This file
├── benchmarks/         # Published benchmark result records
│   └── *.md            # Decision evidence with immutable source citations
├── reference/          # Historical specs, research, external references
│   └── *.md            # Specification documents
├── research/           # Research and analysis artifacts
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

- Research output (needs analysis, competitive landscape, impact scores)
- Problem validation artifacts
- Stakeholder feedback summaries
- Market research findings

### `guides/`

- Development setup instructions
- Deployment procedures
- Troubleshooting guides
- Contribution guidelines

### `benchmarks/`

- Published benchmark results used for repository decisions
- Immutable source, run, commit, and artifact references
- No harnesses, raw responses, worktrees, or unsealed candidate mappings

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
- Repository-wide operating policy → use `AGENTS.md`
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
- [Problem Framing](guides/problem-framing.md) - Conditional problem, audience, alternatives, impact, and user-outcome analysis
- [Design Patterns](guides/design-patterns.md) - Lead index for advisory code-layer pattern catalogs, including concurrency, integration / messaging, and data / persistence citations
- [Repo Orchestration Patterns Reference](guides/repo-orchestration-patterns-reference.md) - Detail for the advisory orchestration vocabulary summarized in `AGENTS.md`
- [Opportunity Feedback Examples](guides/opportunity-feedback-examples.md) - Worked examples for the `opportunity_notes` channel
- [AGENTS.md Section Redirects](guides/agents-md-section-redirects.md) - ADR-021 anchor migration table
- [Model ROI Benchmark Runbook](guides/model-roi-benchmark-runbook.md) - Prepare, synchronize, run, grade, and publish benchmark campaigns

### Benchmarks

- [Agent ROI Benchmark Results](benchmarks/agent-roi-benchmark-results.md) - Model, context, and orchestration score sets
- [Retro Execution 447 Results](benchmarks/retro-execution-447-results.md) - Sequential, monolithic, and parallel retro comparison

### Decisions (ADRs)

- [ADR-001: Context Pack Structure](decisions/adr-001-context-pack-structure.md) - Why we use `.context/` for LLM memory
- [ADR-004: Analyst Role and Feedback Loop](decisions/adr-004-analyst-role-and-feedback-loop.md) - Adding pre-Architect validation and iterative feedback
- [ADR Template](decisions/adr-template.md) - Template for new architecture decisions

### Postmortems / Lessons Learned

- [Postmortems Index](postmortems/README.md) - When to write a postmortem; ADR-vs-postmortem split; "What generalizes" promotion gate
- [Postmortem Template](postmortems/postmortem-template.md) - Template for retrospective lessons

### Reference

- Add specification documents as needed
