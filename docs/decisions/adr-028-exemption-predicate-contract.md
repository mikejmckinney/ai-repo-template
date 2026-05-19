# ADR-028: Exemption Predicate Contract

## Status

Accepted

## Date

2026-05-19

## Enforcement scope

This ADR delivers (a) the predicate library
(`scripts/checks/060-exemption-predicates.sh` and the Python helpers in
`scripts/lib/`), (b) the three registry contracts under
`.context/state/` (`judge_runtime_allowlist.yaml`,
`exemption_label_appliers.yaml`, `adr_exemption_registry.yaml`), and
(c) the Judge attestation header from §A2. Live-PR CI validation that
fetches `parent_compliance.exemptions[]` from open PR bodies and invokes
the predicates against them is a deliberate follow-up tracked in issue
#350. Until that follow-up lands, enforcement is **judge-mediated at
review time** (Judge reads the exemption claim against ADR-028 by hand
and REQUEST_CHANGES on mismatch) and **library-mediated for in-repo
fixtures only** (the predicate library validates the four `kind` values
and registry lookups against fixtures committed under
`scripts/tests/fixtures/`). Treat any "machine-checkable" framing for
live PRs as aspirational until #350 lands.

## Context

ADR-026 introduced parent/subagent compliance contracts (`parent_compliance`,
`subagent_compliance`). Those contracts proved that *evidence shape* can be
mechanically enforced, but they left the **exemption seam** unscoped: a
parent or default agent could mark a PR or plan as exempt from a hard gate
(Analyst pre-flight, plan-as-comment, pre-merge verification, ADR doc-sync,
provenance) by typing the word "exempt" into a checklist line. Issue #349
collected four concrete self-exemption seams:

- **RC1 (Self-Judge)** — the same identity that authored a plan/PR could
  post a Judge plan-gate APPROVE on it (Copilot acting as both implementer
  and reviewer; `mikejmckinney` acting as both author and gate). Nothing
  enforced author-disjoint review.
- **RC2 (Header drift)** — Judge "APPROVE WITH EXEMPTION" decisions had no
  load-bearing surface a validator could anchor on. Decisions claimed
  exemptions in free-form prose, so any heuristic regex over the comment
  body could be silently bypassed by reordering paragraphs.
- **RC3 (Label self-application)** — exemption-bearing labels
  (`chore:no-plan`, `smoke-test`, `outcome-validated`, `cap-override`)
  could be applied by the PR author themselves with no record of who
  applied them and no constraint that the applier was distinct from any
  dispatched subagent.
- **RC4 (Operational-process scope drift)** — the "operational/process"
  exemption used to skip Analyst pre-flight for shared procedural prompts
  (`pr-resolve-all.md`, etc.) lacked a closed set of paths and a fallback
  grep, so any file under `.github/prompts/` could claim exemption simply
  by being a prompt.

ADR-005 (Analyst pre-flight), ADR-011 (plan-as-comment), ADR-014 (gate
extension), ADR-016 (pre-merge verification), and ADR-026 (compliance
contracts) each enumerate *when* a gate applies and *what* opts out, but
none of them enumerate the **machine-checkable predicates** that prove an
opt-out claim. Without that predicate layer, every gate is honor-system
and the audit trail is "the agent said the word `exempt`."

Issue #349 directs us to close those four seams with a closed taxonomy
that DevOps can implement as `scripts/checks/060-exemption-predicates.sh`
(and a Python validator) from this ADR alone.

## Decision

We define a **closed taxonomy of four exemption predicates**. Every claim
of `parent_compliance.exemptions[]` (or a `subagent_compliance.exemptions[]`
equivalent) MUST select exactly one `kind` from this list. Claims using any
other `kind` value are invalid and Judge MUST REQUEST_CHANGES.

| `kind` | Source of truth | Predicate validates |
|---|---|---|
| `judge_decision` | A Judge plan-gate or diff-gate comment posted on the issue or PR | The comment author is on `judge_runtime_allowlist.yaml`, is distinct from the PR/plan author, is not in `parent_compliance.subagents_dispatched[].agent` for the PR, and the comment carries the exact two-line header from §A2 |
| `label` | A label on the issue or PR (e.g. `chore:no-plan`, `smoke-test`, `outcome-validated`, `cap-override`) | The label exists, the gate's own ADR enumerates that label as an opt-out, the label-applier login is NOT in `parent_compliance.subagents_dispatched[].agent` for the PR, and (optionally, when enabled) the applier is on `exemption_label_appliers.yaml` |
| `operational_process` | The PR's diff is fully contained in a closed set of operational-process path globs (§A3) | At least one diff path matches the §A3 glob set OR the PR body grep fallback matches one of the §A3 phrases AND the issue references a shared procedural prompt |
| `adr_clause` | A specific clause in an existing ADR | The cited `clause_id` resolves to an active entry in `adr_exemption_registry.yaml` whose `scope[]` covers the PR's diff or the gate being skipped |

This taxonomy is **closed**: adding a new `kind` requires an ADR amending
this one. The four kinds intentionally cover the four RCs from issue #349.

### §A1 — `judge_decision` predicate (full spec)

**¶1 — Acceptance criteria.** A `judge_decision` exemption is accepted iff
all of the following hold:

- The cited evidence URL resolves to an issue or PR comment on the same
  repository as the PR claiming the exemption.
- The comment's author login is present in
  `.context/state/judge_runtime_allowlist.yaml` `allowlist[].login` and
  NOT present in `revoked[].login`.
- The comment's author login is **author-disjoint** from the claimant: it
  is not equal to the PR's author login, not equal to the linked issue's
  author login, and not equal to any login listed in
  `parent_compliance.subagents_dispatched[].agent` for the PR (the
  subagents_dispatched exclusion, §A1¶4).
- The comment body matches the two-line header regex from §A2.

**¶2 — Allowlist source.** The trusted set is the single file
`.context/state/judge_runtime_allowlist.yaml` (schema
`judge_runtime_allowlist:v1`). Each entry records `{login, kind, added_by,
added_at, notes}`. The `kind` field tags the runtime class (`human`,
`copilot_runtime`, `claude_runtime`, `gemini_runtime`, `workflow_runtime`).
Workflow-mediated identities (e.g. `github-actions[bot]`) are allowed
because Judge dispatches through `claude.yml` and similar workflows post
under those logins; the entry must declare `kind: workflow_runtime` and
the underlying model runtime inherits trust via that posting identity.

Edits to this file are governed by §Registry governance below.

**¶3 — Header regex (load-bearing).** A comment qualifies as a Judge
exemption attestation only when its body matches:

```text
^## Judge — DECISION\s*\n(\s*\n)*DECISION:\s+APPROVE WITH EXEMPTION\s+—\s+\S.+$
```

The regex anchors on two markdown headings/lines:

1. An H2 heading whose text is exactly `Judge — DECISION` (em-dash, single
   space either side).
2. After zero or more blank lines, a line beginning with
   `DECISION: APPROVE WITH EXEMPTION — ` (em-dash) followed by a
   non-empty reason string.

The H2 line is the contract. There is no regex-only fallback that scans
the comment body for "exempt" anywhere — the absence of the H2 header is
itself a rejection (RC2 closure). This is why `.agents/judge.md` declares
the exemption attestation an **exact-output contract** and why the
companion review files (`.cursor/BUGBOT.md`, `.gemini/styleguide.md`,
`.github/copilot-instructions.md`, `.github/workflows/claude.yml`) carry
skip-list notes that `## Judge — DECISION` must NOT be flagged as a
non-conventional heading shape.

**¶4 — `subagents_dispatched` exclusion.** Even if a comment author is on
the runtime allowlist and the comment matches §A2 exactly, the predicate
rejects when that author login appears in
`parent_compliance.subagents_dispatched[].agent` for the same PR. This
closes the self-Judge-via-subagent loophole: a default agent cannot
dispatch itself (or any identity it dispatched) as Judge on its own PR.
The check is per-PR — an identity that was dispatched on PR #N as
`Architect` may still post a valid Judge decision on PR #M provided it
was not dispatched on PR #M.

**¶5 — Grandfather clause (option (a) selected).** For comments where
`comment.created_at < adr_028.merged_at`, the predicate accepts the
attestation **if** the comment matches §A2's two-line header. The
allowlist, author-disjoint, and `subagents_dispatched` exclusion checks
are NOT enforced retroactively, because (i) those signals were not
collected at the time, and (ii) re-running history is not possible. The
grandfather window closes the instant ADR-028 merges; every comment
posted at or after that moment is evaluated against the full predicate.

A residual seam exists where a maintainer could edit a pre-merge comment
*after* the grandfather window closes to add the §A2 header. See §Threat
model for why we accept this seam (option (b)) rather than gate on
`updated_at < merged_at`.

### §A2 — Header contract for exemption attestations

The H2 + `DECISION:` two-line header is the load-bearing surface a
validator anchors on. The full template lives in `.agents/judge.md`
§"Exemption attestation". The exact shape is:

```text
## Judge — DECISION

DECISION: APPROVE WITH EXEMPTION — <reason string>
```

Rules:

1. The H2 text is exact: `## Judge — DECISION` (note the em-dash `—`,
   not a hyphen-minus, and the single space on each side).
2. Zero or more blank lines may separate the H2 from the `DECISION:`
   line.
3. The `DECISION:` line begins at column 1 and matches the regex in
   §A1¶3 verbatim.
4. The reason string after the em-dash is free-form prose but MUST be
   non-empty. Judges SHOULD include enough specificity that a human
   reading the PR audit trail later can tell *why* the exemption was
   granted (e.g. `... — pure-docs PR; doc_sync triggers checked`).
5. The header MAY be followed by any additional review body (REQUIRED
   CHANGES, NICE-TO-HAVES, etc.) without affecting predicate acceptance.

Because the H2 wording is unusual (it intentionally collides with how
some review-style guides flag non-conventional headings), this ADR is
the source of truth that mandates skip-list entries in companion review
files. See `.context/rules/process_doc_maintenance.md` for the doc-sync
trigger that keeps those companions aligned with `.agents/judge.md`
§"Exemption attestation".

### §A3 — `operational_process` predicate path globs and grep fallback

A PR qualifies for an `operational_process` exemption when **either**
condition holds:

**Glob condition.** Every modified path in the PR diff matches at least
one glob in the closed union below:

```text
.github/prompts/**
.github/workflows/**
.github/agents/**
.github/ISSUE_TEMPLATE/**
.github/pull_request_template.md
.github/copilot-instructions.md
.context/rules/process_*.md
.context/state/**
scripts/**
scripts/checks/**
scripts/setup/**
scripts/tests/**
scripts/lib/**
Makefile
install.sh
test.sh
.pre-commit-config.yaml
.pre-commit-config.yaml.template
```

This union is the broadened set per Judge plan-gate v2 RC4 review — it
captures the surfaces where shared procedural prompts, workflow logic,
setup/lint scripts, and process rules live. Any path outside this set
in the diff invalidates the glob condition.

**Grep fallback.** When the diff includes paths outside the glob set,
the predicate falls back to a grep over the PR body for one of these
exact phrases (case-sensitive, substring match):

```text
operational/process per ADR-014
shared procedural prompt
operational_process exemption
exempt per ADR-014
exempt per pr-resolve-all.md
exempt per repo-onboarding.md
exempt per expand-backlog-entry.md
exempt per capture-postmortem.md
exempt per mirror-postmortem.md
```

The grep is a **fallback**, not a primary surface. When the grep matches
but the glob condition fails, the predicate also requires that the linked
issue body references one of the shared procedural prompts enumerated
in ADR-005 (`pr-resolve-all.md`, `repo-onboarding.md`,
`expand-backlog-entry.md`, `capture-postmortem.md`, `mirror-postmortem.md`)
or the prompt directory's `README.md`. Without that issue cross-reference,
free-form prose claiming operational-process exemption is rejected.

### §A4 — `adr_clause` predicate

A `adr_clause` exemption cites a `clause_id` string of the shape
`ADR-NNN#<slug>` (e.g. `ADR-011#plan-as-comment-exemption-≤20LOC-single-role`).
The predicate accepts iff:

- The `clause_id` resolves to an entry in
  `.context/state/adr_exemption_registry.yaml` `entries[]` (not `expired[]`).
- The entry's `expires_at` is `null` or a future ISO date.
- The entry's `scope[]` covers the PR's diff or the gate being skipped.
  Scope strings may be path globs or free-form prose constraints (the
  registry trusts maintainers to author them precisely; Judge cross-checks
  scope plausibility at diff-gate).

Edits to `adr_exemption_registry.yaml` are governed by §Registry
governance below. Superseded entries move to `expired[]` with
`expired_at` and `replacement_clause_id`; entries are **never deleted**,
to preserve the audit trail.

### Registry schemas

The three YAMLs PM seeded under `.context/state/` are the predicate's
source-of-truth files. Their schemas (declared via the top-level `schema:`
key in each file) are:

**`judge_runtime_allowlist.yaml`** (`schema: "judge_runtime_allowlist:v1"`)

```yaml
schema: "judge_runtime_allowlist:v1"
allowlist:
  - login: "<github-login>"
    kind: "human" | "copilot_runtime" | "claude_runtime" | "gemini_runtime" | "workflow_runtime"
    added_by: "<adr-or-pr-reference>"
    added_at: "YYYY-MM-DD"
    notes: "free-form prose"
revoked:
  - login: "<github-login>"
    kind: ...
    added_by: ...
    added_at: ...
    revoked_at: "YYYY-MM-DD"
    reason: "free-form prose"
    notes: ...
```

**`exemption_label_appliers.yaml`** (`schema: "exemption_label_appliers:v1"`)

```yaml
schema: "exemption_label_appliers:v1"
policy:
  enforce: false                   # informational only; default RC3 predicate applies
  enforce_for_labels: []           # subset of label names this allowlist gates
allowlist:
  - login: ...
    kind: ...
    added_by: ...
    added_at: ...
    notes: ...
```

This file is the **optional** alternative path for the `label` predicate.
The default behavior closes RC3 by excluding any login in
`parent_compliance.subagents_dispatched[]` from being a valid
label-applier; maintainers who want defense-in-depth can enable this file
by flipping `policy.enforce: true` and populating `enforce_for_labels`.

**`adr_exemption_registry.yaml`** (`schema: "adr_exemption_registry:v1"`)

```yaml
schema: "adr_exemption_registry:v1"
entries:
  - clause_id: "ADR-NNN#<slug>"
    scope:
      - "<glob-or-prose>"
    expires_at: null | "YYYY-MM-DD"
    granted_by: "<adr-or-pr-reference>"
    notes: "free-form prose"
expired:
  - clause_id: ...
    scope: ...
    granted_by: ...
    notes: ...
    expired_at: "YYYY-MM-DD"
    replacement_clause_id: "ADR-MMM#<slug>" | null
```

### Registry governance

Edits to any of the three registries above require:

1. **A Docs-role PR.** The three YAMLs live under `.context/state/`,
   which Docs owns per `.context/rules/agent_ownership.md`. Non-Docs
   roles MAY propose edits, but the PR opening identity MUST follow
   the dispatch-to-Docs flow.
2. **A Judge plan-gate APPROVE from an identity already on the
   pre-edit allowlist.** The reviewing Judge identity must appear in
   `judge_runtime_allowlist.yaml` `allowlist[]` *as the file existed
   before the PR's diff applies*. This forbids bootstrapping new
   trust via the same PR that grants it.
3. **Self-referential edits require a second allowlisted Judge.** When
   the PR adds or removes an identity from
   `judge_runtime_allowlist.yaml`, the reviewing Judge identity must
   not be the identity being added or removed. A second Judge from the
   pre-edit allowlist must also APPROVE. This closes the seam where a
   single trusted identity could quietly bootstrap or revoke other
   identities.
4. **Revocations move, never delete.** Entries withdrawn from the
   active set MUST move to the `revoked[]` (or `expired[]`) array with
   the required additional fields. The audit trail is the point.

### Threat model — residual risks

Closing RC1/RC2/RC3/RC4 leaves a small set of residual risks. We enumerate
them so future ADRs can address them if a real exploit materializes:

- **Comment edit after grandfather window closes** (Judge plan-gate v2
  Special Item C). A maintainer with edit permission on a pre-merge
  comment could add the §A2 header to a comment that was created before
  ADR-028 merged but did not originally carry the header. The predicate
  would accept it under §A1¶5. We deliberately chose **option (b),
  accept and document** rather than option (a) `require updated_at <
  merge` because:
  1. **Friction for legitimate typo fixes.** Option (a) would reject any
     comment with a post-merge edit, which would punish authors who fix
     a typo in a perfectly valid pre-merge attestation.
  2. **Bounded window.** The grandfather clause closes at merge. Every
     comment created after that moment is evaluated under the full
     predicate (including `subagents_dispatched` exclusion), so the
     residual exposure is limited to the small population of pre-merge
     comments and cannot grow.
  3. **GitHub preserves edit history.** Forensic recovery is possible.
     A reviewer who suspects an edit-attack can inspect the comment's
     edit history via the GitHub UI or REST API.
  4. **Higher-value seams are closed.** RC1 (self-Judge) and RC3
     (subagent self-labeling) were the load-bearing exploits identified
     in issue #349. Closing those eliminates the predominant attack
     surface; the `updated_at` seam is a strictly weaker residual that
     does not materially change the threat profile.
- **Registry-file edit collusion.** Two colluding maintainers on the
  allowlist could grant a third unsafe identity through the §Registry
  governance §3 path. Mitigation is social, not technical: the audit
  trail (Docs-PR, Judge approvals, file history) is durable, and any
  collusion is recoverable via revocation.
- **Workflow-mediated identity laundering.** `github-actions[bot]`
  posts under one login regardless of which underlying model runtime
  produced the text. A workflow that dispatches an unsafe model could
  post Judge attestations under that allowlisted identity. Mitigation
  lives in workflow-file change control (`.github/workflows/**` is
  Copilot-only writable via branch protection).
- **Operational-process glob drift.** Adding a new path glob to §A3
  broadens the exemption surface. Mitigation: glob edits require an
  ADR amending this one, and Judge enforces that via the doc-sync
  trigger in `process_doc_maintenance.md`.

## Options Considered

### Option 1: Free-form prose attestation (status quo)
- **Pros**: Zero implementation cost; flexible.
- **Cons**: Honor-system; every gate is bypassable by typing "exempt";
  no audit trail beyond the comment body.

### Option 2: Closed taxonomy with machine-checkable predicates (chosen)
- **Pros**: Validator can mechanically prove or reject every exemption
  claim; closes the four RCs from issue #349; audit trail is the three
  registry files plus the Judge comment.
- **Cons**: Adds registry-file maintenance overhead; new gate kinds
  require an ADR amendment.

### Option 3: Forbid exemptions entirely
- **Pros**: Maximally strict; nothing to validate.
- **Cons**: Real PRs legitimately need to skip gates (pure-docs PRs,
  shared procedural prompts, ≤20 LOC OP direct-implementation per
  ADR-011). A blanket ban would either block legitimate work or push
  authors to claim false in-scope status.

## Consequences

### Positive

- Every exemption claim is mechanically verifiable from this ADR + the
  three registry YAMLs.
- The audit trail is durable in-repo (registry files) and on-GitHub
  (Judge comments, label-applier history).
- DevOps can implement `scripts/checks/060-exemption-predicates.sh`
  and `scripts/lib/exemption_predicates.py` from this ADR alone.
- Self-Judge, label self-application, and operational-process scope
  drift are all closed by predicates rather than honor-system prose.

### Negative

- Registry governance adds friction to adding new trusted identities
  or new ADR clauses — every such edit needs a Docs PR + Judge APPROVE.
- The `## Judge — DECISION` H2 has an unusual shape that some review
  agents may flag as non-conventional; skip-list notes in companion
  review files mitigate this but add cross-file coupling.
- The grandfather clause's `updated_at` seam is documented but not
  closed.

### Neutral

- This ADR does NOT supersede prior ADRs. It adds a new contract on
  top of ADR-026 (compliance contracts v1). ADR-005, ADR-011, ADR-014,
  and ADR-016 remain authoritative for *when* their respective gates
  apply; ADR-028 governs *how* exemption claims are validated.

## Implementation

- [x] Seed `.context/state/judge_runtime_allowlist.yaml`,
      `.context/state/exemption_label_appliers.yaml`, and
      `.context/state/adr_exemption_registry.yaml` (PM, pre-Phase 4).
- [x] Add `## Exemption attestation` section to `.agents/judge.md`. (Delivered in issue #349 PR.)
- [x] Add reciprocal review responsibility to `.agents/critic.md`. (Delivered in issue #349 PR.)
- [x] Add doc-sync trigger row to
      `.context/rules/process_doc_maintenance.md`. (Delivered in issue #349 PR.)
- [x] Add skip-list notes to `.cursor/BUGBOT.md`,
      `.gemini/styleguide.md`, `.github/copilot-instructions.md`. (Delivered in issue #349 PR.)
- [x] Update `.context/state/README.md` to index the three registries. (Delivered in issue #349 PR.)
- [x] Update `AI_REPO_GUIDE.md` to catalog the three registries. (Delivered in issue #349 PR.)
- [x] Update `docs/guides/multi-agent-coordination.md` with the
      exemption-attestation flow. (Delivered in issue #349 PR.)
- [x] Implement `scripts/checks/060-exemption-predicates.sh` and
      `scripts/lib/exemption_predicates.py`. (Delivered in issue #349 PR; live-PR CI integration deferred to follow-up #350.)
- [x] Add fixtures under
      `scripts/tests/fixtures/exemptions/` covering the four
      `kind` values, the grandfather window, the
      `subagents_dispatched` exclusion, and §A3 glob/grep fallback. (Delivered in issue #349 PR — 41 fixtures.)
- [ ] **Follow-up (issue #350):** Live-PR CI parsing of
      `parent_compliance.exemptions[]` from open PR bodies + reconcile
      `_OP_PROCESS_FALLBACK_REQUIRED_PHRASES` with §A3 text.

## Migration

The grandfather clause (§A1¶5) keys on
`comment.created_at < adr_028.merged_at`. Operationally:

1. The merge commit SHA of the PR introducing ADR-028 is recorded
   as the boundary.
2. The validator reads `adr_028.merged_at` from a one-line constant
   file (`scripts/lib/exemption_predicates.py` may hard-code it from
   git history at first install; preferred long-term is a small
   `.context/state/adr_028_boundary.yaml` containing `merged_at:
   <ISO timestamp>` and `merge_commit_sha: <sha>`).
3. Comments created before the boundary are evaluated under the
   reduced predicate (§A2 header match only).
4. Comments created at or after the boundary are evaluated under the
   full predicate (§A1¶1 conjunction).

The boundary never moves. There is no second grandfather window.

## Supersession

This ADR does NOT supersede any prior ADR. It is an additive contract
layered on top of:

- **ADR-026** (compliance contracts v1) — ADR-028 defines the
  predicates that validate `parent_compliance.exemptions[]` claims
  whose evidence shape ADR-026 already enforces.
- **ADR-005, ADR-011, ADR-014, ADR-016** — each ADR continues to
  enumerate when its gate applies and what labels/conditions opt out;
  ADR-028 adds the predicate layer that proves the opt-out claim.

If a future ADR changes the predicate taxonomy (adds, removes, or
re-scopes a `kind`), that ADR MUST supersede this one in the standard
way and update the registry schemas in lockstep.

## References

- ADR-005 (Analyst pre-flight gate) — `docs/decisions/adr-005-analyst-preflight-gate.md`
- ADR-011 (Plan-as-comment requirement) — `docs/decisions/adr-011-plan-as-comment-requirement.md`
- ADR-014 (Extend pre-flight to ad-hoc deliverables) — `docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md`
- ADR-016 (Pre-merge verification gate) — `docs/decisions/adr-016-pre-merge-verification-gate.md`
- ADR-023 (Shared subagent canonical) — `docs/decisions/adr-023-shared-subagent-canonical.md`
- ADR-025 (GitHub issues + PR comments as live state) — `docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md`
- ADR-026 (Compliance contracts v1) — `docs/decisions/adr-026-compliance-contracts.md`
- Issue #349 — closing self-exemption seams (RC1–RC4)
- Judge plan-gate v2 APPROVAL — https://github.com/mikejmckinney/ai-repo-template/issues/349#issuecomment-4490239202
- `.context/state/judge_runtime_allowlist.yaml`
- `.context/state/exemption_label_appliers.yaml`
- `.context/state/adr_exemption_registry.yaml`
