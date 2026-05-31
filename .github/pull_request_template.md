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

## Live agent state

<!-- Optional unless the work is paused, blocked, awaiting review, or being handed off.
     Link the latest `agent-state:v1` issue/PR comment; do not duplicate its
     blocker/handoff text here. -->

- **Latest `agent-state:v1` comment:** <link or "N/A — work completes in this PR without handoff">

## Plan revision sync (REQUIRED when applicable)

<!-- If a plan revision comment was posted on the linked issue AFTER this
     PR was opened, the `## Plan` section above must include the revision
     link and a refreshed "Latest in 1–2 sentences" line. Tick the matching
     box below so reviewers don't evaluate stale intent. -->

- [ ] No post-open plan revision comment was posted on the linked issue.
- [ ] Post-open plan revision comment was posted; `## Plan` section above is updated with the revision link and a refreshed summary.

## Parent compliance (ADR-026)

<!-- REQUIRED for non-exempt work. This records what the parent/default agent
     loaded and how role dispatch/gates were handled. Copy parsed
     `subagent_compliance` objects into `subagents_dispatched`; do not leave
     only raw YAML-in-YAML. CI validates declared evidence shape only — it
     does not prove Copilot runtime dispatch or handoff execution. -->

```yaml
parent_compliance:
  handshake_token: "Session handshake v<N>"
  agents_md_version: <N>
  runtime_pointer:
    path: .github/copilot-instructions.md
    loaded: "<true | false>"
    decision_affected: "<specific decision affected, or null when exempt>"
  applicable_roles:
    - "<role>"
  subagents_dispatched:
    - role: "<role>"
      role_contract_version: 1
      agents_md_version: <N>
      receipt:
        mode: "<visible-line | trailing-block>"
        value: "<receipt evidence>"
      context_files_used:
        - AGENTS.md
        - .agents/<role>.md
      pointers_skipped: []
      task_scope: "<parent-assigned task scope>"
      files_modified:
        - "<path or omit entry if empty list>"
      gates_invoked:
        - "<gate name>"
      run_status: "<SUCCESS | PARTIAL | BLOCKED_ON_RUNTIME | NEEDS_CONTEXT>"
  monolithic_justification: "<null or required one-sentence justification>"
  plan_gate:
    status: "<linked | pending | exempt>"
    link: "<URL or null>"
    gate_status:
      triggered: <true | false>
      applied: <true | false>
  diff_gate:
    status: "<pending | linked | exempt>"
    link: "<URL or null>"
    gate_status:
      triggered: <true | false>
      applied: <true | false>
  adr_required:
    required: "<true | false>"
    link: "<path/URL or null>"
  deviations:
    - planned: "<planned behavior>"
      actual: "<actual behavior>"
      reason: "<why acceptable>"
  verification_results:
    - command: "<command>"
      result: "<pass | fail | sandbox-deferred | n/a>"
      evidence: "<one-line pointer>"
```

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

**Evidence:**

- <link/excerpt/transcript/screenshot/checklist result>

**Result:** <problem statement resolved | not resolved | framing disconnect | blocked>

**Explanation:**
<brief explanation>

## Sandbox dogfood evidence

<!-- REQUIRED Both labels MUST
     point to real sandbox URLs (issue link and PR link). Refer to the [sandbox 
     verification playbook](../docs/guides/sandbox-verification.md) which details the 
     process for using sandbox and which sandbox instance to use.
     Advisory drift detector: `scripts/checks/157-sandbox-evidence-labels.sh`. -->

Sandbox issue: <URL>
Sandbox PR: <URL>

## Supporting verification

<!-- REQUIRED. Exact commands you ran (or N/A for docs-only). These are
     supporting regression/hygiene evidence; they do not replace the
     primary user-outcome validation above. -->

- [ ] `<command>` — pass / fail
- [ ] Manual check: `<step>` — result

## Supporting verification results (REQUIRED — Judge enforces at diff-gate)

<!-- Mirror your plan's `### Supporting verification` section 1:1. Every command
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

## Opportunity notes

<!-- Optional. Up to 3 out-of-scope improvement opportunities surfaced
     during the work that produced this PR. Each entry uses the
     9-field shape defined in
     `.context/rules/process_opportunity_feedback.md` § "Required
     fields (9 total)". Cap is ≤3 per session per agent. Omit this
     section or write "None" if nothing to surface; do not fold
     opportunities into the PR scope. -->

- None

## Risks / rollback

<!-- One paragraph: what could break, how to revert. "Low risk, fully
     reversible" is acceptable for trivial PRs. -->

## Provenance

<!-- Cite repo files (path:line where it matters) for any factual claim
     about the codebase made above. Per AGENTS.md §"Critical thinking",
     uncited claims are treated as assumptions. Skip for trivial PRs. -->
