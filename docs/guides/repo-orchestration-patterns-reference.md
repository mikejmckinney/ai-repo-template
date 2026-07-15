# Repository Orchestration Patterns Reference

This advisory vocabulary describes structure; an identifier alone never blocks a
change. ADR-031 applies these patterns through one implementing agent, optional
local consensus, retained workflow adapters, and owner-keyed GitHub state.

## Active Patterns

- **P1 Strategy:** the implementing agent selects task-appropriate techniques;
  local consensus supplies independent perspectives only when justified.
- **P2 Chain of Responsibility:** deterministic workflow stages short-circuit on
  explicit pass/fail outcomes.
- **P3 Mediator:** GitHub issues, PRs, and `agent-state:v1` comments coordinate
  work without hidden peer state.
- **P4 Adapter:** provider-specific runners wrap canonical advisory/retro contracts.
- **P5 Template Method:** issues, plans, PRs, ADRs, and retro artifacts use stable
  skeletons with task-specific content.
- **P6 Facade:** `AGENTS.md`, `AI_REPO_GUIDE.md`, and prompt entrypoints expose
  smaller canonical contracts.
- **P7 Owner-Keyed Concurrent State:** branches, issues, PRs, and run keys
  partition concurrent writes.
- **P8 Canonical Manifest:** repeated labels, review lenses, and lifecycle values
  have one source with parity checks where worthwhile.
- **P9 Multi-Model Plan Consensus:** retained only through explicit use of the
  OpenCode `local-consensus` skill.

## Anti-Patterns

- **AP1 God Object:** one file accumulates unrelated responsibilities.
- **AP2 Mirror Duplication:** substantive policy is copied across consumers.
- **AP3 Implicit Contract:** correctness depends on undocumented ordering.
- **AP4 Goal Substitution:** artifacts ship without enabling the user action.
- **AP5 Sequential Coupling:** useful work requires unnecessary ordered ceremony.
- **AP6 Single-Writer Shared State:** concurrent work mutates one unpartitioned record.
- **AP7 Magic String Sprawl:** identifiers drift across unvalidated consumers.
- **AP8 Workflow-as-Application:** business logic lives in workflow YAML instead of tested scripts.
- **AP9 Compatibility Surface Entrenchment:** retired paths remain normal dependencies.
- **AP10 Undifferentiated Infrastructure Ownership:** project-owned runners,
  images, services, or update pipelines duplicate a maintained platform
  capability without a verified requirement or measurable benefit. Prefer the
  platform capability and its maintenance boundary. Custom infrastructure is
  justified when demonstrated compliance, isolation, performance, or
  reproducibility needs outweigh its lifecycle cost.

Historical role-registry and multi-agent examples remain in superseded ADRs and
benchmark artifacts. They are evidence, not active operational triggers.
