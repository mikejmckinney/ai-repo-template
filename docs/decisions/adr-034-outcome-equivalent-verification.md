# ADR-034: Outcome-equivalent verification and auditable evidence

## Status

Accepted

Partially supersedes ADR-029 sections 1-3 and 8. ADR-016 remains active.

This decision partially supersedes ADR-029 without rewriting its historical
rationale.

## Date

2026-07-23

## Context

ADR-016 introduced a sibling repository to close a specific GitHub
verifiability gap: some workflows are loaded from a default branch and cannot
execute candidate workflow code from an upstream PR branch. ADR-029 later made
links to a sandbox issue and PR mandatory for every PR.

The universal destination became a proxy for outcome validation. It could force
static or provider-hosted changes through an unrelated repository without
reproducing the user's journey. It also allowed the linked issue and PR to
repeat observed claims without an inspectable artifact proving external state.
PR #520 demonstrated both problems: the derived-repository operation needed a
fresh disposable repository and redacted API evidence, while its dispatch-only
workflow separately needed the sibling repository's default branch and a real
dispatch run.

## Decision

User-outcome validation is the umbrella discipline. End-to-end testing,
integration testing, rendered-document review, metadata inspection, and
operational walkthroughs are methods selected according to the outcome.

For each material claim, use the most representative practical environment. It
must preserve the load-bearing trigger, lifecycle phase, entrypoint,
permissions, fresh state, platform/runtime, representative configuration, and
observable result. Cost, speed, safety, reversibility, and resource use
distinguish options only after those conditions are preserved.

Isolation is preferred when it does not reduce fidelity; it is not a universal
requirement. A mixed change can require more than one environment.

Every material claim must publish an inspectable evidence artifact. External
state and runtime claims cannot be prose-only. Evidence records:

- the material claim and selected environment;
- why that environment is representative;
- the implementation SHA;
- the action, expected result, and observed result;
- an artifact and artifact type;
- redaction and PR-lifetime retention information;
- any earlier-SHA reuse justification; and
- pass, fail, or blocked status.

Prefer machine-generated API output, command transcripts, real-trigger run
URLs, and request/response records. Screenshots are a fallback when the
platform has no safer export. Critical excerpts or durable locators remain in
the issue or PR for the PR lifetime. Expiring or authenticated artifacts state
their access and expiration. Disposable resources remain available until
capture completes.

Automation validates evidence shape, provenance, and locators. Human review
assesses semantic representativeness. Artifact presence improves auditability;
it is not independent proof that an author chose the correct environment.

The sibling repository remains the adapter for GitHub behavior that requires
candidate code on a default branch. The candidate workflow must be placed on
the required ref and its real event fired. A copied branch or unrelated green
CI run is insufficient.

### Clarification (2026-07-25)

Environment selection prioritizes evidentiary fidelity, not minimum spend or
effort. A generate, send, deploy, publish, write, or external-mutation outcome
therefore requires one representative real operation. Startup, metadata
inspection, mocks, and tool listing remain supporting evidence when the
affected user's action and required observable result have not occurred.

When that operation spends money or is destructive, the author must obtain
explicit approval and bound it to the smallest representative action. The
outcome remains `blocked` while approval is pending; after the action is
performed, its observed result determines `pass` or `fail`.

## ADR relationships

ADR-016 remains active and owns deterministic workflow-trigger classification
plus the sibling-repository adapter for default-branch GitHub behavior.

This ADR partially supersedes ADR-029 as follows:

- Section 1's universal sibling-repository requirement is replaced by
  outcome-equivalent environment selection and material claim evidence.
- Section 2's universal `Sandbox issue:` and `Sandbox PR:` labels are replaced
  by conditional artifact locators in the canonical evidence record.
- Section 3's structural-versus-semantic principle remains, but structural
  checks now validate the evidence schema rather than two sandbox URLs.
- Section 8's universal transition rule is superseded.
- Section 1.1's per-finding `reproduced`, `skipped_collateral`, `fixed`, and
  `cant_reproduce` semantics remain active. Automated fix PRs render this
  ADR's evidence contract and keep sandbox synchronization as an operational
  adapter only when a default-branch workflow requires it.
- ADR-029's canary placeholder, schema-history, and historical rationale
  remain unchanged.

## Consequences

### Positive

- Review evidence is tied to the user outcome instead of a universal location.
- Material external/runtime observations remain inspectable after disposable
  resources are removed.
- Static, fresh-state, preview, and default-branch changes can use different
  environments without weakening the outcome gate.
- Mixed changes expose rather than hide their multiple verification surfaces.

### Negative

- Authors must identify material claims and redact artifacts before publishing.
- Private or expiring evidence needs a durable PR excerpt and retention note.
- Semantic fidelity remains a human judgment that cannot be fully automated.

## Verification

- Contract tests reject prose-only external-state evidence.
- Generated issue plans and the PR template expose the canonical fields.
- Fix-PR rendering uses the same outcome evidence contract.
- The classifier retains deterministic trigger detection and points to the
  outcome guide plus the specialized sibling-repository playbook.
- Dogfood covers static documentation, real default-branch workflow behavior,
  and a fresh-state or provider-preview journey with redacted artifacts.

## References

- Issue #517
- Issue #316
- PR #520
- ADR-016
- ADR-029
- `docs/guides/outcome-validation.md`
- `docs/guides/sandbox-verification.md`
