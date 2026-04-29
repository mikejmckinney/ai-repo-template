# ADR-015: Postmortem feedback loop from downstream projects

## Status

Accepted

## Date

2026-04-29

## Context

Issue [#150](https://github.com/mikejmckinney/ai-repo-template/issues/150)
proposed four mechanisms for closing the feedback loop from projects
built *from* this template back into the template itself: (1) postmortem
scaffolding, (2) downstream-project registry, (3) cross-project scaffold
reuse, (4) issue mining + learn-from-downstream prompt. Step 1 (the
postmortem template + README) shipped in #151. Steps 2–4 were left
deliberately unbuilt pending evidence that the volume of downstream
incidents justified the build cost.

By April 2026 we had two real downstream incidents to reason about:

- **CMMC reference repo** — the workflow-bypass incident captured in
  [`postmortem-001-workflow-bypass.md`](../postmortems/postmortem-001-workflow-bypass.md),
  which produced [ADR-012](./adr-012-explicit-workflow-preconditions.md).
  Mirrored ad hoc; the procedure was invented PR-by-PR.
- **`mikejmckinney/cloud_migration_POC`** — the prompts-1-through-6-
  produced-architecture-instead-of-working-demo incident, remediated
  by adding [`07-working-demo-upgrade.md`](https://github.com/mikejmckinney/cloud_migration_POC/blob/4943212140cbcec760221ba405b437d678a26771/.github/prompts/07-working-demo-upgrade.md).
  Captured here as `postmortem-002`.

Two cases is enough to expose the problem postmortem-001 papered over:
the procedure for *capturing* a downstream postmortem and *deciding what
of it should flow back to the template* was undocumented. The next
incident would re-invent both wheels. It also exposed a subtler issue:
some lessons are universal (they apply to every repo built from the
template), while others are stack-specific (Terraform behavior,
Python-runtime behavior, etc.). Without an explicit place to record
stack-specific lessons, the implicit options were (a) pollute AGENTS.md
with per-stack tips, or (b) lose the lessons entirely. Both are bad.

Two cases is **not** enough to justify a registry, a webhook, an
auto-mirror workflow, or an issue-mining pipeline. Building infrastructure
for an N=2 problem is the kind of premature scaffolding the template's
own conventions warn against.

## Decision

Adopt a **manual, prompt-driven, three-tier feedback loop** as v1. Defer
all automation until N≥3 downstream incidents have flowed through it.

Specifically:

1. **Capture procedure** — `.github/prompts/capture-postmortem.md`. Run
   in the downstream project repo. Walks the agent through the existing
   postmortem template, forces an explicit `What generalizes` decision,
   and requires YAML frontmatter (new in this ADR — see #4 below) that
   includes a stack-tag list.

2. **Sync-back procedure** — `.github/prompts/mirror-postmortem.md`.
   Run against `ai-repo-template`. Validates the source postmortem's
   frontmatter and `follow_up_artifact`, refuses to mirror without a
   concrete same-PR follow-up, copies the body verbatim with a
   provenance header, and updates the stack-tagged index.

3. **Three-tier promotion policy** — recorded in
   `docs/postmortems/README.md`:

   - **Universal** lesson (applies to any repo regardless of stack) →
     follow-up amends `AGENTS.md`, `.context/rules/`, a prompt, or
     adds a new ADR. The mirrored postmortem documents the incident;
     the rule lives in the conventional surface.
   - **Stack-specific** lesson (applies only to repos using a named
     stack) → follow-up is the mirrored postmortem + its row in the
     stack-tagged index. **Does not** modify AGENTS.md or
     `.context/rules/`. This is the load-bearing constraint of this
     ADR; without it, AGENTS.md will accumulate Terraform / Python /
     Rust / etc. tips and become unreadable.
   - **Project-only** lesson → stays in the source repo's postmortem.
     Not mirrored.

4. **Frontmatter schema** — every file in `docs/postmortems/postmortem-*.md`
   carries a YAML frontmatter block: `postmortem_number`, `date`,
   `source_repo`, `source_commit`, `stacks: []`, `generalizes`,
   `follow_up_artifact`, `mirror_status`. Existing
   `postmortem-001-workflow-bypass.md` is retroactively updated to
   conform; the body is unchanged (per immutability rule).

5. **Stack-tagged index** — `docs/postmortems/README.md` carries a
   hand-maintained index grouping mirrored postmortems by stack tag.
   Auto-generation from frontmatter is a follow-up; for v1 the
   maintenance cost (one bullet per mirror, ≤monthly) is below the
   cost of building the generator.

6. **Test invariants** — `test.sh` enforces (a) every postmortem file
   has the required frontmatter, and (b) both new prompt files exist.
   Index-completeness is *not* enforced by `test.sh` in v1 — the
   manual-maintenance cost of fixing an index-test failure during a
   mirror PR exceeds the cost of a missed bullet, and the bullet's
   audience is humans browsing the README.

## Alternatives considered

- **Build the registry (#150 mechanism 2) now.** Rejected. With N=2
  downstream projects and no automated cross-cutting analysis, the
  registry is an empty file plus a YAML schema. Its actual value
  appears at N≥5, when scanning "which other projects use Terraform"
  becomes useful. Build it then.

- **Auto-mirror workflow (webhook on downstream postmortem merge).**
  Rejected. Triggers GitHub-app permissions complexity, and the
  three-tier classification is genuinely a judgment call — there is no
  good way to automate "is this universal or stack-specific?" The
  prompt-driven version makes the human / agent do that classification
  explicitly. The audit trail is better.

- **Promote stack-specific lessons to AGENTS.md as long as they're
  small.** Rejected. The slope is real: postmortem-002's lesson
  ("verify deliverable shape per-sequence, not per-prompt") is
  arguably universal but emerged from a stack-specific incident. The
  three-tier policy makes that judgment a deliberate ADR-or-rule edit,
  not an ambient drift.

- **`learn-from-downstream.md` prompt (#150 mechanism 4).** Rejected
  for v1; reconsider after `mirror-postmortem.md` has fired ≥3 times.
  Premature without observed patterns of what cross-project mining
  actually surfaces.

- **Auto-generate the stack-tagged index from frontmatter.** Deferred,
  not rejected. At v1 maintenance volume (≤1 mirror/month) the
  generator costs more than it saves. Revisit when index drift has
  been observed.

## Consequences

**Positive**:

- Next downstream postmortem follows a documented procedure instead of
  re-inventing one.
- AGENTS.md is protected from per-stack drift by an explicit policy
  with a named alternative (the postmortem itself).
- Stack-specific lessons become discoverable instead of being lost or
  awkwardly bolted onto rules.
- The `follow_up_artifact != none` validation in
  `mirror-postmortem.md` operationalizes the existing README rule
  ("mirroring without a follow-up is not permitted") that was
  previously honor-system.

**Negative / risks**:

- Manual mirroring scales poorly past N≈5. The trigger for revisiting
  this ADR is documented in #1 above.
- The three-tier classification is judgment-driven; there will be edge
  cases. ADR is the place to record the precedents as they accumulate.
- The stack-tagged index is hand-maintained; index drift is possible.
  Mitigation: a `test.sh` invariant for index completeness is a
  candidate follow-up, deferred per #6 above.
- Frontmatter schema additions are a breaking change for any external
  tool that already parses `docs/postmortems/postmortem-*.md`. There
  is no such tool today; `postmortem-001` is updated in the same PR.

## References

- [Issue #150](https://github.com/mikejmckinney/ai-repo-template/issues/150) — feedback loop proposal
- [PR #151](https://github.com/mikejmckinney/ai-repo-template/pull/151) — postmortem scaffolding (step 1)
- [`docs/postmortems/postmortem-001-workflow-bypass.md`](../postmortems/postmortem-001-workflow-bypass.md) — the ad hoc precedent
- [`docs/postmortems/postmortem-002-poc-outcome-mismatch.md`](../postmortems/postmortem-002-poc-outcome-mismatch.md) — first end-to-end run of this procedure
- [`07-working-demo-upgrade.md`](https://github.com/mikejmckinney/cloud_migration_POC/blob/4943212140cbcec760221ba405b437d678a26771/.github/prompts/07-working-demo-upgrade.md) — cloud_migration_POC remediation
- [ADR-005](./adr-005-analyst-preflight-gate.md) — pre-flight gate (related; per-prompt outcome validation)
- [ADR-014](./adr-014-extend-preflight-to-adhoc-deliverables.md) — pre-flight extension (related)
