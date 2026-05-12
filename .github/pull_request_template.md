<!--
Pull request template. Keep concise; reviewers expect to scan this in
<30 seconds. Sections marked REQUIRED are enforced by Judge at diff-gate
(see .github/agents/judge.agent.md). Delete any section that's genuinely
N/A — empty headings are noise.
-->

## Summary

<!-- 1–3 sentences: what this PR changes and why. -->

## Linked issues / ADRs

<!-- REQUIRED. Judge BLOCKs at diff-gate when this is empty unless an
     ADR-011 exemption applies: exemption label (chore:no-plan,
     smoke-test), known automation bot author (Renovate, Dependabot),
     or revert PR. An ADR-only reference (e.g. "Implements ADR-007")
     also satisfies the link requirement. See ADR-011. -->

**Closes / Refs:** #

<!-- Examples: "Closes #42", "Refs #100", "Implements ADR-007".
     For follow-up PRs, link the parent PR by its number: "Refs #123"
     (PRs and issues share the same number space on GitHub). -->

## Live coordination state (post-ADR-025)

<!-- Per ADR-025 (issue #298), the live coordination baton lives in the
     latest `agent-state:v1` comment on the linked issue (or this PR
     once it exists). Link the latest comment so reviewers and the next
     session can find continuation state without scrolling. Skip if no
     `agent-state:v1` comment is needed (e.g., trivial single-commit PR
     with no handoff). -->

- **Latest `agent-state:v1` comment:** <permalink, or "N/A — no continuation state needed">

## Plan

<!-- Pointer to the implementation plan comment(s) on the linked issue.
     Per ADR-011, the plan lives on the issue, not here — this section
     is the breadcrumb so reviewers always land on the latest version.
     Update this when you post a "Plan revision" comment.
     Skip (or write "N/A — <reason>") only when an ADR-011 plan
     exemption applies (chore:no-plan, automation bot, revert).
     Note: smoke-test exempts only from the PR-link rule, not from
     the plan requirement.
     Judge advises (REQUEST_CHANGES) at diff-gate when missing or
     stale; not a v1 BLOCK. -->

- **Original plan:** <link to plan comment, e.g. https://github.com/.../issues/42#issuecomment-NNN>
- **Revisions:** <links to any "Plan revision" comments, or "none">
- **Latest in 1–2 sentences:** <current outcome + approach>

## Plan revision sync (REQUIRED when applicable)

<!-- If a plan revision comment was posted on the linked issue AFTER this
     PR was opened, the `## Plan` section above must include the revision
     link and a refreshed "Latest in 1–2 sentences" line. Tick the matching
     box below so reviewers don't evaluate stale intent. -->

- [ ] No post-open plan revision comment was posted on the linked issue.
- [ ] Post-open plan revision comment was posted; `## Plan` section above is updated with the revision link and a refreshed summary.

## Verification

<!-- REQUIRED. Exact commands you ran (or N/A for docs-only). -->

- [ ] `<command>` — pass / fail
- [ ] Manual check: `<step>` — result

## Verification results (REQUIRED — Judge enforces at diff-gate)

<!-- Mirror your plan's `### Verification` section 1:1. Every command
     listed in the plan must have a result entry here BEFORE the PR
     enters review. CI is a backstop, not a substitute for local
     verification (issue #208/#225 lessons learned).

     For each verification step in the plan, post one of:
       - `✅ pass` + a one-line evidence pointer (CI run URL, log
         excerpt, or local-output snippet)
       - `❌ fail` + what failed and why it's acceptable to merge
         anyway (rare; usually means re-do the work)
       - `⏭️ sandbox-deferred — see Phase 2` for items the plan
         declared `Verification target: sandbox repo` (ADR-016)
         that cannot be exercised from a same-repo PR branch
       - `⏭️ N/A — <reason>` if the plan section was N/A

     Exemptions match the Plan-as-comment rule (ADR-011): PRs labeled
     `chore:no-plan` or `smoke-test`, automation-bot authors
     (Renovate, Dependabot), and reverts are skipped. -->

- [ ] `<command from plan>` — ✅ pass — <evidence pointer>
- [ ] Manual: `<step from plan>` — ✅ pass — <one-line result>

## Doc sync (REQUIRED — Judge enforces at diff-gate)

Walk `.context/rules/process_doc_maintenance.md`'s trigger table. Tick each
companion that needed updating, OR state `<file>: no changes required` with
a one-line justification.

- [ ] `AI_REPO_GUIDE.md` updated (or: `AI_REPO_GUIDE.md: no changes required — <why>`)
- [ ] ADR added/superseded (or: `ADR: no changes required — <why>`)
- [ ] `docs/guides/multi-agent-coordination.md` updated (or: `not required — <why>`)
- [ ] Role changes mirrored across registries and `agent_ownership.md` (or: `not required — <why>`)
- [ ] `.context/rules/<file>.md` added/updated (or: `not required — <why>`)
- [ ] Workflow inline-prompt mirrors updated alongside `.github/prompts/*.md` edits (or: `not required — <why>`)
- [ ] `scripts/setup.sh` `_ensure_label` list updated alongside pipeline label additions (or: `not required — <why>`)
- [ ] `test.sh` / `install.sh` updated for new template files (or: `not required — <why>`)
- [ ] Cadence/format changes updated in READMEs and templates (or: `not required — <why>`)

## Risks / rollback

<!-- One paragraph: what could break, how to revert. "Low risk, fully
     reversible" is acceptable for trivial PRs. -->

## Provenance

<!-- Cite repo files (path:line where it matters) for any factual claim
     about the codebase made above. Per AGENTS.md §"Critical thinking",
     uncited claims are treated as assumptions. Skip for trivial PRs. -->
