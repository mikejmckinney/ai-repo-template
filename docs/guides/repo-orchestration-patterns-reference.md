# Repository Orchestration Patterns Reference

This advisory vocabulary describes structure; an identifier alone never blocks a
change. ADR-031 applies these patterns through one implementing agent, optional
local consensus, retained workflow adapters, and owner-keyed GitHub state.
The marked catalog below is canonical. Run
`python3 scripts/generate-pap-catalog.py` after changing it; do not edit the
generated `AGENTS.md` catalog directly.

<!-- canonical:pap-catalog:begin -->
### Patterns in use

- **P1 Strategy (role specialization - deprecated):** role files provide focused strategies
  selected when specialization is worth the overhead; routine implementation
  still defaults to one agent.
- **P2 Chain of Responsibility (pipeline):** staged handlers have explicit
  pass/block criteria and short-circuit on a blocking result. The full pipeline
  is optional, not the routine default.
- **P3 Mediator (coordination):** a coordinator or explicit live-state surface
  resolves cross-agent dependencies instead of peer-to-peer hidden state.
- **P4 Adapter:** provider-specific runners wrap canonical advisory and retro
  contracts. The former multi-registry role adapters are deprecated.
- **P5 Template Method (skeletal artifacts):** plans, PRs, ADRs, and review
  artifacts use stable skeletons while allowing task-specific content.
- **P6 Facade (tool-specific entry points):** `AGENT.md`, `AI_REPO_GUIDE.md`, and
  tool instructions remain thin entry points to canonical contracts.
- **P7 Owner-Keyed Concurrent State:** concurrent state is partitioned by branch,
  issue, PR, role, or another explicit owner so independent writes can merge.
- **P8 Canonical Manifest with Generated Surfaces:** frequently repeated values
  or structures have one canonical source and deterministic native consumers
  with freshness checks when tools cannot follow a direct pointer.
- **P9 Multi-Model Plan Consensus:** high-risk or ambiguous work may compare up
  to three isolated candidate plans and synthesize one reviewable plan. It is an
  explicit opt-in technique, not default fan-out.
- **P10 Classifier:** a deterministic classifier maps explicit observed attributes
  to an operational class while keeping classification separate from the action
  taken for that class. `scripts/workflows/lib/finding_priority.py` classifies post-merge retro and weekly review findings from impact, trigger likelihood, fix cost, and regression-guard value into reviewable priority bands.

### Anti-patterns to watch

- **AP1 God Object:** one file accumulates unrelated reasons to change, making
  review and context loading unreliable. Signals include many unrelated top-level
  concerns, repeated cross-domain edits, and inability to review the file in one
  focused pass. Remediate by separating stable policy from task-specific detail,
  but do not split always-needed policy into mandatory rereads.
- **AP2 Mirror Duplication:** identical substantive content is manually copied
  across files. Keep one canonical body and use pointers, symlinks, thin
  adapters, or deterministic generation where native formats are unavoidable.
- **AP3 Implicit Contract:** correctness depends on an ordering, precondition, or
  convention that exists only in contributor memory. Encode it in the closest
  contract, type, test, or workflow predicate.
- **AP4 Goal Substitution:** a change produces requested artifacts but misses the
  user action they were meant to enable. State outcomes in do-language and test
  the observable journey, not only file or endpoint existence.
- **AP5 Sequential Coupling:** useful work requires reading or executing a long
  ordered chain before the first meaningful action. Remove redundant steps and
  load task-specific context only when triggered.
- **AP6 Single-Writer Shared State:** parallel writers mutate one unpartitioned
  state record, causing conflicts or lost updates. Partition by owner or move
  coordination to a system with explicit concurrency semantics.
- **AP7 Magic String Sprawl:** labels, variables, identifiers, or route names are
  duplicated across consumers without validation. Centralize when repetition is
  frequent; otherwise add a focused cross-check when the second consumer lands.
- **AP8 Workflow-as-Application:** substantial business logic lives inside
  workflow YAML where it is difficult to test or reuse. Keep workflows as event
  wiring and move complex logic into tested scripts or actions.
- **AP9 Compatibility Surface Entrenchment:** a replacement is accepted, but the
  deprecated path remains a normal operational dependency. Stop extending the
  old surface and retire, archive, or clearly demote it.
- **AP10 Disproportionate Solution Complexity:** a solution adds custom
  components, abstractions, infrastructure, or process whose lifecycle cost is
  not justified by a verified requirement or measurable benefit. Prefer the
  simplest maintained capability that satisfies the outcome. Additional
  complexity is justified only by demonstrated constraints such as compliance,
  isolation, performance, extensibility, or reproducibility.
- **AP11 Probability Neglect:** risk handling focuses on the emotional salience
  or mere possibility of an outcome while ignoring its likelihood, exposure
  window, expected impact, mitigation cost, or opportunity cost. This can
  produce excessive prevention for rare bounded risks while common material
  risks remain under-addressed. Classify probability and impact separately,
  account for reversibility and affected scope, compare mitigations by expected
  benefit and cost, and state the evidence and uncertainty behind the
  classification.
<!-- canonical:pap-catalog:end -->

Historical role-registry and multi-agent examples remain in superseded ADRs and
benchmark artifacts. They are evidence, not active operational triggers.
