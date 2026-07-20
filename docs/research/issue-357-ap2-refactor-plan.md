# Issue 357 AP2 Refactor Plan

Status: Draft planning record

Date: 2026-07-20

Related issue: [#357](https://github.com/mikejmckinney/ai-repo-template/issues/357)

Planning PR: [#497](https://github.com/mikejmckinney/ai-repo-template/pull/497)

This file records the maintainer-approved direction before issue 357 is
rebaselined. The issue body remains the future live implementation contract.
The repository-wide open-issue audit requested after this plan must validate
the final relationship between issue 357, parent issue 279, and overlapping
children before implementation begins.

## Outcome

A maintainer can change each governed concept in one canonical source, generate
native files where tools require them, and receive blocking failures only for
deterministic contract violations. Contextual orchestration anti-patterns remain
advisory review vocabulary rather than generic CI failures.

## Settled Decisions

- AP2 covers manually maintained substantive facts or policy that require
  lockstep edits.
- Git repository mirroring, postmortem promotion, GitHub's `synchronize` event,
  state synchronization, and ordinary behavioral regression tests are outside
  AP2 scope.
- Preserve accepted and superseded ADR and postmortem bodies as historical
  records. Add current-state amendments only where readers could mistake old
  implementation details for active guidance.
- Prefer direct references and filesystem symlinks when consumers support them.
- When a tool requires a complete native file, use a canonical source plus
  deterministic generation. Test the generator and generated-output freshness,
  not parity between independently authored sources.
- `docs/guides/repo-orchestration-patterns-reference.md` is the comprehensive
  canonical P1-P10/AP1-AP11 source.
- `AGENTS.md` retains a concise, self-contained catalog for post-compaction
  awareness. That bounded block is generated from a marked concise block in the
  canonical guide rather than edited independently.
- Use layered enforcement: deterministic structural violations may block;
  contextual architectural signals remain advisory.
- Do not add a new workflow when `test.sh`, Bats, advisory review, or weekly
  review can host the check.
- Rebaseline existing issue 357 instead of creating or superseding it.
- Deliver the approved scope through one broad issue and PR, using phased,
  independently green commits and explicit rollback boundaries.
- Correct the `workflow_dispatch` classifier disagreement in the same PR.
- Dispatch-only workflow changes require sandbox default-branch verification.
  A workflow with a `pull_request` trigger and optional `workflow_dispatch`
  remains PR-branch verifiable.

## Fusion Provenance

The review used the repository's multi-model-consensus Fusion pattern. Fable
and Grok completed their primary panels. Kimi failed and Sol completed that
panel as the configured fallback. Sol also served as judge, so the result is a
practical synthesis with judge overlap rather than fully independent consensus.

Resumable sessions retained for related review work:

- Sol panel: `ses_082aa6ba2ffeUXzBc9q1DG40Hb`
- Fable panel: `099accd4-2c97-45e1-9efd-c0491ce75c10`
- Grok panel: `4b994bc5-6148-4e37-acaf-62686d531e9d`
- Sol judge: `ses_082a39fa3ffesGF3YMBvO6RUxQ`

## Findings

### 1. The P/AP catalog is manually duplicated and has drifted

`AGENTS.md` and `docs/guides/repo-orchestration-patterns-reference.md`
independently define P1-P10 and AP1-AP11. P4 and P8 already have materially
different meanings. This is confirmed AP2 duplication.

### 2. Issue 357 and its parent hierarchy are stale

Issue 357 targets role registries, role mirrors, and workflows retired by
ADR-031. Parent issue 279 and several children still assume Copilot labels,
budget variables, role overlays, and deleted workflow surfaces. Rebaselining
the issue hierarchy is a prerequisite to implementation.

### 3. The workflow verification matrix is dual-authored and inconsistent

`docs/guides/agent-pipeline.md` classifies `workflow_dispatch` as requiring the
sandbox default branch. `scripts/verify-pr.sh` currently groups workflows that
have only `pull_request` or `workflow_dispatch` as PR-branch verifiable. The
classifier and its behavior tests must become authoritative; prose should point
to them instead of maintaining a second trigger list.

### 4. Native issue templates repeat one plan skeleton

The feature, bug, and initialization issue templates each contain an identical
implementation-plan skeleton. GitHub requires complete physical template files,
so a canonical fragment plus deterministic generation is appropriate.

### 5. Runtime profiles duplicate a security boundary

`.github/agent-runtime/review.json` and `fix.json` repeat disabled MCP entries,
the read-only GitHub MCP, and default-deny policy. Their edit permission and
step budgets intentionally differ. Generation must preserve direct security
tests for lockdown, enabled-server sets, and review/fix permission differences.

### 6. Development MCP inventory is duplicated across host schemas

`.mcp.json` and `.opencode/opencode.json` describe similar MCP inventories using
incompatible schemas and environment-variable syntax. Netlify intentionally
uses a different OpenCode transport. A neutral inventory with explicit host
overrides is preferable to independently authored configurations. Cursor's
existing symlink to `.mcp.json` should remain.

### 7. Active guidance contains removed paths and procedures

The PR template references removed check 157, a nonexistent `AGENTS.md`
documentation-synchronization table, retired inline prompt mirrors, and an
obsolete setup path. `scripts/tests/README.md` still describes removed legacy
test wrappers. `scripts/verify-pr.sh` points to a removed fixture script.
ADR-029 describes removed drift-check and Judge surfaces as active enforcement.

### 8. Invariant checks cannot be deleted wholesale

Checks 046, 049, 052, 053, and 126 mix literal synchronization checks with real
security, permissions, deduplication, concurrency, artifact-scoping, sandbox,
schema, and incident-regression contracts. Every assertion requires an explicit
keep, replace, or remove disposition before modification.

## Candidate Inventory

| Surface | Planned treatment |
|---|---|
| P/AP catalog | Canonical guide block generates bounded `AGENTS.md` block |
| Workflow verification | Executable classifier owns behavior; prose points to it |
| Issue-template plan blocks | Canonical slim fragment generates three native blocks |
| Runtime review/fix profiles | Shared security source plus explicit overlays generate JSON |
| Development MCP configs | Neutral inventory plus host overrides generate host forms |
| Cursor MCP config | Preserve symlink to root `.mcp.json` |
| Pipeline labels | Retain current structured label block initially; derive bounded tests |
| Checks 046/049/052/053/126 | Per-assertion keep/replace/remove disposition |
| Historical ADRs/postmortems | Preserve bodies; add current-state amendments where needed |
| Git/postmortem mirroring | Out of AP2 scope |
| Stale PR/test guidance | Correct active references and remove obsolete instructions |

## Enforcement Matrix

An AP identifier never blocks by itself. A blocking result requires a concrete,
deterministic contract violation.

| AP | Enforcement mode | Existing or planned path |
|---|---|---|
| AP1 God Object | Advisory; H1 may independently block demonstrated unrelated responsibilities | Advisory and weekly review |
| AP2 Mirror Duplication | Block stale generated output, broken pointers, and independently authored declared-generated surfaces | Generator `--check`, Bats, `test.sh` |
| AP3 Implicit Contract | Block encoded schema or contract violations; advise on newly discovered assumptions | Existing focused checks and review |
| AP4 Goal Substitution | Existing manual outcome gate; missing required evidence blocks | Issue plan, PR template, sandbox validation |
| AP5 Sequential Coupling | Advisory only | Advisory and weekly review |
| AP6 Single-Writer Shared State | Block missing owner keys where a concurrent schema exists and known retired-state reintroduction | Existing state/retired-path checks |
| AP7 Magic String Sprawl | Block undeclared identifiers only in bounded structured fields | Focused validator, Bats, `test.sh` |
| AP8 Workflow-as-Application | Advisory; line count is evidence, not a verdict | Advisory and weekly review |
| AP9 Compatibility Entrenchment | Block known retired paths and active references to removed surfaces | Focused dead-reference predicates |
| AP10 Disproportionate Complexity | Advisory only | PR and advisory review |
| AP11 Probability Neglect | Advisory only | PR and advisory review |

Do not add a generic anti-pattern scanner or a blocking workflow line-count
ceiling. Both would create high false-positive rates and exemption theater.

## Phased Implementation

### Phase 0: Rebaseline Issue 357 and open the implementation draft

- Rewrite issue 357 around current `main` while preserving discussion history.
- Update parent issue 279 and disposition overlapping child issues.
- Fill one `implementation-plan:v2` block in the rebaselined issue.
- Preserve this file as research evidence, not a second live plan.

Rollback boundary: GitHub issue and draft-PR metadata only.

### Phase 1: Ratify canonical ownership and layered enforcement

Likely files:

- `docs/decisions/adr-032-canonical-governance-sources.md`
- `docs/decisions/README.md`
- `docs/guides/repo-orchestration-patterns-reference.md`
- `AGENTS.md`

The ADR records source ownership, generation rules, historical-record policy,
and deterministic-versus-advisory enforcement.

Rollback boundary: ADR and catalog ownership only.

### Phase 2: Generate the concise AGENTS catalog

Likely components:

- `scripts/generate-pap-catalog.py`
- `scripts/tests/generated-governance-surfaces.bats`
- A focused numbered generated-output check discovered by `test.sh`

TDD order:

1. Add a failing stale-output test.
2. Mark the canonical concise block in the guide.
3. Add the generator and generate the bounded `AGENTS.md` block.
4. Prove deterministic and idempotent output.

Rollback boundary: guide markers, generator, and generated AGENTS block.

### Phase 3: Correct workflow verification classification

Likely files:

- `scripts/verify-pr.sh`
- `scripts/tests/verify-pr.bats`
- `docs/guides/agent-pipeline.md`
- `docs/guides/sandbox-verification.md`
- `.github/PLAN_TEMPLATE.md`
- `scripts/checks/130-adr016-invariants.sh`

Required behavior:

- `pull_request` with optional `workflow_dispatch`: PR-branch verification.
- Dispatch-only: sandbox default branch.
- Existing default-only triggers: sandbox verification.
- Correct the removed fixture pointer in `scripts/verify-pr.sh`.
- Replace the prose trigger inventory with a pointer to executable behavior and
  a concise explanation of verification classes.

Rollback boundary: classifier, fixtures, and verification documentation.

### Phase 4: Remove stale active guidance

- Correct `.github/pull_request_template.md`.
- Replace the obsolete migration text in `scripts/tests/README.md`.
- Add current-state amendments to ADR-020, ADR-021, and ADR-029 where needed.
- Add focused assertions for active references to known removed paths.
- Do not scan or rewrite all historical prose.

Rollback boundary: stale-reference cleanup only.

### Phase 5: Generate native issue-plan skeletons

Likely components:

- One canonical slim implementation-plan fragment.
- A generator that updates only `implementation-plan:v2` marker blocks.
- Bats coverage for idempotency, stale headings, missing markers, and
  preservation of template-specific surrounding content.

`.github/PLAN_TEMPLATE.md` remains the detailed planning guide and has a
different reason to change from the slim issue fragment.

Rollback boundary: fragment, generator, and three generated marker blocks.

### Phase 6: Add bounded label enforcement

- Retain `_PIPELINE_LABEL_SPECS` as the active label source initially.
- Derive generic active-label tests from that structured block.
- Keep hardcoded tests only for semantic requirements and retired-label absence.
- Validate known structured workflow/setup label-reference positions.
- Exclude historical ADRs, examples, and arbitrary Markdown prose.

Rollback boundary: validator and derived tests; label creation remains intact.

### Phase 7: Generate runtime security profiles

- Introduce a shared security source and explicit review/fix overlays.
- Generate complete runnable `review.json` and `fix.json` files.
- Preserve direct assertions for default deny, enabled MCP set, read-only and
  lockdown headers, dedicated token, and review/fix edit permissions.
- Do not derive runtime authorization automatically from development MCP state.

Rollback boundary: runtime source, overlays, generator, and generated profiles.

### Phase 8: Generate development MCP host configurations

- Introduce one neutral MCP inventory with explicit per-host overrides.
- Generate `.mcp.json` and only the `mcp` object in OpenCode configuration.
- Preserve Netlify transport differences, environment dialects, OCI opt-in,
  and the Cursor symlink.
- Leave unrelated OpenCode provider/model settings directly authored.

Rollback boundary: MCP inventory, generator, and generated host sections.

### Phase 9: Triage existing invariant assertions

The PR body records every assertion removed from checks 046, 049, 052, 053,
and 126 and names its replacement.

Keep assertions that protect:

- Permissions and security boundaries.
- Incident-linked regressions.
- Cross-file behavioral interfaces.
- Schemas and generated-output contracts.
- Deduplication, concurrency, artifact scoping, and sandbox credentials.
- Known retired-path absence.

Remove an assertion only when the duplicate authored source has been eliminated,
replacement validation is green, and no behavior or security contract is lost.

Rollback boundary: invariant cleanup only.

### Phase 10: Full validation and sandbox dogfood

Supporting local verification:

```bash
bash test.sh
bats --jobs 4 scripts/tests/
bash scripts/lint-shell-conventions.sh scripts/
python3 scripts/check-markdown-links.py <changed-markdown-files>
git diff --check
```

Every generator must support check-only operation.

User-outcome validation:

1. Change the guide catalog and generate `AGENTS.md`.
2. Stale the generated block and confirm validation names the canonical source
   and repair command.
3. Change the issue fragment and regenerate all issue templates.
4. Add an undeclared structured label and confirm bounded validation fails.
5. Remove an MCP lockdown field and confirm security tests fail.
6. Change one neutral MCP entry and confirm host outputs update while intentional
   overrides remain.
7. Exercise dispatch-only and PR-plus-dispatch classifier cases.
8. Confirm a long declarative workflow does not fail solely for line count.

Required sandbox evidence:

- Create a real issue using a generated issue template.
- Open a linked sandbox PR using the updated PR template.
- Exercise dispatch-only behavior from the sandbox default branch.
- Exercise a PR-triggered workflow that also supports manual dispatch.
- Record real `Sandbox issue:` and `Sandbox PR:` URLs.

## Issue-Hierarchy Reconciliation

The repository-wide open-issue audit must verify these provisional dispositions:

- Issue 357: rebaseline and retain as the implementation issue.
- Issue 279: rebaseline parent scope after ADR-031.
- Issue 283: retain only current label-source work that remains unimplemented;
  remove retired Copilot labels and unverified manifest assumptions.
- Issue 284: likely obsolete because the described Copilot label state machine
  is retired.
- Issue 285: re-evaluate against current workflows because its target workflow
  no longer exists.
- Issue 286: separate bounded label validation from unrelated shell-linter
  fixture coverage.
- Issue 371: replace the blocking line ceiling with advisory AP8 evidence or
  close it as not planned.

These are review hypotheses, not final issue mutations.

## Risks

The maintainer selected one broad issue and PR despite the separate policy,
generator, security, template, and classifier rollback surfaces. This creates
an AP10 risk. Mitigate it with phased commits, a green endpoint after each
phase, per-phase rollback documentation, and no mixed catch-all cleanup commit.

Generated files can conceal security changes in large diffs. Runtime profile
generation therefore retains direct semantic security assertions and requires
review of source plus generated diff.

Text-similarity and keyword scanners have unacceptable false-positive rates for
AP2. Enforcement must operate only on declared generated surfaces, structured
identifiers, known retired paths, and explicit schemas.
