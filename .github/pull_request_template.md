<!--
Pull request template. Keep concise; reviewers expect to scan this in
<30 seconds. Sections marked REQUIRED are checked by maintainers and CI.
Delete any section that's genuinely
N/A — empty headings are noise.
-->

## Summary

<!-- 1–3 sentences: what this PR changes and why. -->

## Linked issues / ADRs

<!-- REQUIRED unless an
     ADR-011 exemption applies: exemption label (chore:no-plan,
     smoke-test), known automation bot author (Renovate, Dependabot),
     or revert PR. An ADR-only reference (e.g. "Implements ADR-007")
     also satisfies the link requirement. See ADR-011. -->

**Closes / Refs:** #

<!-- Examples: "Closes #42", "Refs #100", or
     "Implements [ADR-007](https://github.com/OWNER/REPO/blob/COMMIT/docs/decisions/adr-007-<slug>.md)".
     For follow-up PRs, link the parent PR by its number: "Refs #123"
     (PRs and issues share the same number space on GitHub). -->

## Plan

<!-- Pointer to the linked issue's implementation-plan:v2 block, or to the
     grandfathered implementation-plan:v1 comment. The plan lives on the issue,
     not here. Edit the canonical plan in place when intent changes.
     Skip (or write "N/A — <reason>") only when an ADR-011 plan
     exemption applies (chore:no-plan, automation bot, revert).
     Note: smoke-test exempts only from the PR-link rule, not from
     the plan requirement.
     Keep this pointer current when the plan changes. -->

- **Canonical plan:** <link to the issue-body plan or grandfathered v1 comment>
- **Latest in 1–2 sentences:** <current outcome + approach>

## Live agent state

<!-- Optional unless the work is paused, blocked, awaiting review, or being handed off.
     Link the latest `agent-state:v1` issue/PR comment; do not duplicate its
     blocker/handoff text here. -->

- **Latest `agent-state:v1` comment:** <link or "N/A — work completes in this PR without handoff">

## Plan sync

<!-- Confirm that the canonical issue plan contains the current merged plan,
     including a bounded revision-history entry for material changes. -->

- [ ] Canonical plan and current summary match this PR.

## User outcome validation — PRIMARY

<!-- REQUIRED for non-exempt work. This proves the issue problem statement was
     tested against the issue's User outcome / 15-minute test. Generic script,
     lint, schema, or CI output belongs in Supporting verification unless it
     directly performs the user outcome. -->

**Problem statement tested:** <yes/no>

**User outcome / 15-minute test performed:** <yes/no>

**Steps performed:**

1. <step>
2. <step>
3. <step>

## User outcome evidence

<!-- REQUIRED for each material outcome claim. Repeat this record as needed.
     External-state and runtime claims cannot be prose-only. Prefer scoped,
     machine-generated evidence over screenshots; redact before publication.
     See docs/guides/outcome-validation.md. -->

**Material claim:** <observation whose falsity changes the outcome conclusion>

**Environment:** <selected adapter>

**Why representative:** <load-bearing conditions preserved>

**Implementation SHA:** <tested SHA>

**Action performed:** <actual user action>

**Expected result:** <expected observation>

**Observed result:** <actual observation>

**Artifact:** <durable link or embedded redacted excerpt>

**Artifact type:** <API output | run URL | transcript | request/response | screenshot | rendered checklist>

**Redaction:** <what was removed, or why no sensitive data was present>

**Retention:** <PR-lifetime record plus access/expiration disclosure>

**Evidence reuse:** <none, or earlier-SHA unchanged-path/condition justification>

**Result:** <problem statement resolved | not resolved | framing disconnect | blocked>

**Explanation:**
<brief explanation>

## Supporting verification

<!-- REQUIRED. Exact commands you ran (or N/A for docs-only). These are
     supporting regression/hygiene evidence; they do not replace the
     primary user-outcome validation above. -->

- [ ] `<command>` — pass / fail
- [ ] Manual check: `<step>` — result

## Supporting verification results (REQUIRED)

<!-- Match your plan's `### Supporting verification` section 1:1. Every command
     listed in the plan must have a result entry here BEFORE the PR
     enters review. CI is a backstop, not a substitute for local
     verification (issue #208/#225 lessons learned).

     For each verification step in the plan, post one of:
       - `✅ pass` + a one-line evidence pointer (CI run URL, log
         excerpt, or local-output snippet)
       - `❌ fail` + what failed and why it's acceptable to merge
         anyway (rare; usually means re-do the work)
       - `⏭️ environment-deferred — <adapter + reason>` for items that
         cannot be exercised from a same-repo PR branch
       - `⏭️ N/A — <reason>` if the plan section was N/A

     Exemptions match the Plan-as-comment rule (ADR-011): PRs labeled
     `chore:no-plan` or `smoke-test`, automation-bot authors
     (Renovate, Dependabot), and reverts are skipped. -->

- [ ] `<command from plan>` — ✅ pass — <evidence pointer>
- [ ] Manual: `<step from plan>` — ✅ pass — <one-line result>

## Doc sync (REQUIRED)

Follow `AI_REPO_GUIDE.md` § "Documentation Synchronization". Tick each companion
that needed updating, or state `<file>: no changes required` with a one-line
justification.

- [ ] `AI_REPO_GUIDE.md` updated (or: `AI_REPO_GUIDE.md: no changes required — <why>`)
- [ ] ADR added/superseded (or: `ADR: no changes required — <why>`)
- [ ] Review lifecycle documentation updated (or: `not required — <why>`)
- [ ] Review lifecycle docs updated alongside `.github/prompts/*.md` edits (or: `not required — <why>`)
- [ ] `scripts/setup/40-ensure-labels.sh` updated alongside pipeline label additions (or: `not required — <why>`)
- [ ] `test.sh` / `install.sh` updated for new template files (or: `not required — <why>`)
- [ ] Cadence/format changes updated in READMEs and templates (or: `not required — <why>`)

## Opportunity notes

<!-- Optional. Up to 3 out-of-scope improvement opportunities surfaced
     during the work that produced this PR. Each entry uses the
     eight-field shape defined in `AGENTS.md` § "Opportunity feedback".
     Cap is ≤3 per session per agent. Omit this
     section or write "None" if nothing to surface; do not fold
     opportunities into the PR scope. -->

- None

## Risks / rollback

<!-- One paragraph: what could break, how to revert. "Low risk, fully
     reversible" is acceptable for trivial PRs. -->

## Provenance

<!-- Cite repo files (path:line where it matters) for any factual claim
     about the codebase made above. Per AGENTS.md §"Critical thinking",
     uncited claims are treated as assumptions. Render citations as Markdown
     links or full GitHub URLs rather than plain text. Skip for trivial PRs. -->
