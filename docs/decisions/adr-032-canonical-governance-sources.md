# ADR-032: Canonical Governance Sources And Layered Enforcement

## Status

Accepted

## Date

2026-07-20

## Context

Repository governance contains facts and policy that tools require in different
native formats. Independently maintaining those forms has already produced
different P4 and P8 definitions in `AGENTS.md` and the orchestration-patterns
guide. Similar duplication exists in issue-plan skeletons, runtime security
profiles, and development MCP configuration.

ADR-020 originally made the P/AP vocabulary a binding rules-layer contract and
assigned standalone blocking designations to contextual anti-patterns. ADR-031
later retired the role-based review pipeline. Current review policy instead
requires a concrete failure mode; an AP identifier alone does not block.

This decision supersedes ADR-020 in part. It changes catalog ownership and the
blocking model while preserving the stable P1-P10/AP1-AP11 vocabulary and its
historical rationale.

## Decision

Governed concepts have one authored canonical source. Consumers use a direct
reference or filesystem symlink when their host supports it. When a host
requires a complete native file, a deterministic generator produces that file
or a bounded marked section.

The comprehensive P/AP catalog lives in
`docs/guides/repo-orchestration-patterns-reference.md`. Its marked catalog
generates the bounded `AGENTS.md` catalog. `AGENTS.md` remains self-contained for
post-compaction recovery but is not an independent catalog source.

Generated surfaces must provide a check-only command that fails with the
canonical source and repair command. Tests validate deterministic output,
idempotency, missing markers, and preservation of content outside bounded
markers.

Enforcement is layered:

- Deterministic violations of an encoded contract may block. Examples include
  stale generated output, broken pointers, missing owner keys in an existing
  concurrent-state schema, undeclared identifiers in bounded structured fields,
  known retired paths, schemas, and security invariants.
- Contextual architectural signals remain advisory. AP1, AP5, AP8, AP10, and
  AP11 require evidence of concrete harm; file size, keywords, or an AP label
  alone never block.
- Existing behavior, security, incident-regression, and lifecycle tests are not
  mirror checks merely because they compare multiple files. Remove a
  synchronization assertion only after its independently authored duplicate is
  gone and replacement validation is green.

## Options Considered

### Keep Independently Authored Consumers

- **Pros:** No generator code or generated diffs.
- **Cons:** Requires lockstep edits and has already drifted.

### Replace Every Consumer With A Pointer

- **Pros:** Minimal duplication and simple ownership.
- **Cons:** GitHub templates, OpenCode profiles, and MCP hosts require complete
  native files and cannot consume Markdown pointers.

### Canonical Sources With Thin Adapters Or Generation

- **Pros:** One authored source while retaining valid native consumer formats;
  stale output is mechanically detectable.
- **Cons:** Generators and their semantic security tests become maintained code.

The third option is selected. It is limited to repeated facts that genuinely
share one reason to change; it does not justify a universal governance manifest.

## Consequences

### Positive

- A maintainer edits one source for each governed concept.
- Native files remain usable by tools that cannot follow pointers.
- Blocking checks are tied to deterministic contracts instead of subjective
  anti-pattern detection.
- Historical ADR and postmortem bodies remain intact.

### Negative

- Generated diffs can conceal meaningful security changes unless source and
  generated output are reviewed together.
- Every generator needs focused tests and a check-only path.
- Source ownership is distributed by concern rather than concentrated in one
  universal manifest.

### Neutral

- Symlinks remain preferable where all supported hosts preserve them.
- Contextual AP findings remain available to advisory and weekly review.

## Implementation

- [x] Make the patterns guide canonical and generate the bounded `AGENTS.md`
  catalog.
- [ ] Make the executable workflow classifier authoritative over prose.
- [ ] Generate native issue-plan skeletons from one slim fragment.
- [ ] Generate runtime profiles from a shared security source plus overlays.
- [ ] Generate development MCP host forms from a neutral inventory plus
  explicit overrides.
- [ ] Add resumable Fusion output and provenance contracts.
- [ ] Triage synchronization assertions in checks 046, 049, 052, 053, and 126.

## Verification

- Generator check-only modes name their canonical source and repair command.
- Focused tests stale each generated surface, regenerate it, and prove a second
  generation is a no-op.
- Direct security and behavior assertions remain green after source
  consolidation.
- The issue #357 user-outcome and sandbox tests exercise the maintained workflow.

## References

- [Issue #357](https://github.com/mikejmckinney/ai-repo-template/issues/357)
- [Parent issue #279](https://github.com/mikejmckinney/ai-repo-template/issues/279)
- [ADR-020](./adr-020-orchestration-patterns-reference.md), superseded in part
  by this decision
- [ADR-031](./adr-031-agent-model-roi-benchmark-policy.md)
- `docs/guides/repo-orchestration-patterns-reference.md`
