<!--
Pull request template. Keep concise; reviewers expect to scan this in
<30 seconds. Sections marked REQUIRED are enforced by Judge at diff-gate
(see .github/agents/judge.agent.md). Delete any section that's genuinely
N/A — empty headings are noise.
-->

## Summary

<!-- 1–3 sentences: what this PR changes and why. -->

## Linked issues / ADRs

<!-- e.g. "Closes #NN", "Implements ADR-007", "Tracked by #100".
     If none, write "none". -->

## Verification

<!-- REQUIRED. Exact commands you ran (or N/A for docs-only). -->

- [ ] `<command>` — pass / fail
- [ ] Manual check: `<step>` — result

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
