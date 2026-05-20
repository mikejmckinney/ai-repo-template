<!--
Implementation Plan template (#164).

Copy the block below into a comment on the issue you're about to work on.
Post it BEFORE writing implementation code.

When this template applies:
  - Default: every issue you're about to implement.
  - Skip only for the ADR-011 exemptions: issue (or PR) labeled
    `chore:no-plan`, author is a known automation bot (Renovate,
    Dependabot), or the PR is a revert of a prior PR. Size,
    obviousness, and "trivial fix" are intentionally NOT exemptions —
    see ADR-011 for the rationale.
  - When in doubt, write the plan. Three sentences per section is fine.

There is intentionally no "minimal" vs "full" mode — the template scales
with the work. For trivial sections, write `N/A — <one-phrase reason>`
rather than omitting them. Explicit "I considered this and it doesn't
apply" beats silent omission.

v1 has no formal approval gate (see ADR-011). The plan is a documented
artifact reviewed at PR-time. Approval-gating, expiry rules, and
automated CI enforcement are deferred to issue #155.

If your actual diff diverges from the plan by more than ~30% in file count
or scope, post a "Plan revision" comment on the same issue before pushing
the divergent code, so reviewers see what changed and why.

After posting the plan comment (or any revision), copy the comment's
permalink into the PR's `## Plan` section and refresh the
"Latest in 1–2 sentences" line. The PR body is the breadcrumb that
sends reviewers to the canonical version on the issue; an out-of-date
breadcrumb is the failure mode this template is here to prevent.

If the revision happens after a PR is already open, do that refresh in
the same push as the divergent code and tick the matching box in the
PR template's `## Plan revision sync` section, so re-runs don't
evaluate stale intent.
-->

## 📋 Implementation Plan

**Issue:** #<number>
**Role:** <analyst | architect | backend | frontend | devops | docs | qa | pm>

### Outcome

<One sentence. What user-observable change ships when this is merged?>

### Approach

<Two-to-five sentences. The strategy you chose and one alternative you
considered with why it was rejected. If the approach is obvious from the
issue, write "Direct implementation per issue.">

### Files to change

- `path/to/file1` — <one phrase: what change>
- `path/to/file2` — <one phrase: what change>

<!-- List every file you expect to touch. If the actual diff exceeds this
list by more than ~30%, post a revised plan before pushing. -->

### Model tier

**Tier**: <top | mid | cheap>
**Justification (required when `top`)**: <one line: why this task warrants High-tier dispatch above the role default>

<!-- Per-task override on top of the role defaults set in ADR-019.
     Default is `mid`. Use `top` only when the task genuinely needs Opus-class
     reasoning (novel architecture, irreversible decision, complex review
     gate). Use `cheap` only for trivial mechanical work (typo fixes,
     dependency bumps, generated-file regeneration). When in doubt, leave
     at `mid`. The role default still applies if the dispatcher honors it;
     this field is the implementer's signal to a human or PM about whether
     to upshift before dispatching. -->

### Compliance evidence (ADR-026)

```yaml
plan_compliance:
     applicable_roles:
          - <role>
     instruction_resources:
          -
               resource: AGENTS.md
               why_applicable: Canonical startup, truth hierarchy, and process-rule index.
               evidence: AGENTS_MD_VERSION <N>; Session handshake v<N> emitted.
               decision_affected: <specific plan choice affected by this resource>
          -
               resource: .context/rules/<rule>.md
               why_applicable: <why this rule applies to the work>
               evidence: <what was loaded or checked>
               decision_affected: <specific plan choice affected by this resource>
     role_dispatch:
          decision: "<staged-dispatch | monolithic | exempt>"
          planned_subagents:
               - <role>
          monolithic_justification: <null or one-sentence justification>
     plan_gate:
          status: "<pending | linked | exempt>"
          link: <URL or null>
          gate_status:
               triggered: <true | false>
               applied: <true | false>
     adr_required:
          required: "<true | false>"
          link: <path/URL or null>
          supersession_notes:
               - <ADR status update or N/A>
     doc_sync:
          triggered: "<true | false>"
          companions:
               - <path or N/A>
          no_change_justifications:
               - "<path>: <reason>"
     verification:
          - <exact command or manual check>
```

<!-- Keep this block specific. Generic evidence such as "read all docs" is
           not useful; name the resource, why it applied, and what decision it
           changed. Use `role_contract_version` only in subagent returns, never
           `overlay_version`. See `docs/compliance_schemas.md`. -->

### User outcome validation plan — PRIMARY

**Issue problem statement:** <one-sentence summary>

**User outcome / 15-minute test to perform:**

1. <step from issue>
2. <step from issue>
3. <step from issue>

**Evidence to capture in PR:**

- <artifact, citation, screenshot, command transcript, review checklist, etc.>

**Pass condition:**

- <what proves the problem statement is resolved>

**Failure / framing-disconnect condition:**

- <what would prove the implementation or issue framing is wrong>

<!-- This is the PRIMARY validation gate. The supporting verification
     section below covers regression/hygiene evidence (./test.sh, lint,
     CI, schema checks, sandbox runs). A green CI run with no
     user-outcome evidence is not ready for review. See
     `.context/rules/process_work_style.md` § Validation. -->

### Supporting verification

**Change class**: <code-or-docs | pull_request-triggered workflow | default-branch-only workflow | mixed>
**Verification target**: <PR branch | sandbox repo | both>

<!-- Pick the most-restrictive class your diff touches. The classifier in
     `scripts/verify-pr.sh` will compare your declaration against the
     actual changed paths and flag mismatches. The full trigger-event
     matrix lives in `docs/guides/agent-pipeline.md` § "Workflow
     verifiability matrix" — use it when you're unsure which bucket
     applies. Default-branch-only changes MUST be verified in the
     sandbox sibling repo before merging here (see ADR-016 and
     `docs/guides/sandbox-verification.md`). -->

<How a reviewer can prove this works. Specific commands, specific assertions,
specific test names. "Tests pass" is not sufficient — name them.>

<!-- Each command listed here must have a matching result entry in the
     PR's `## Supporting verification results` section before the PR enters review.
     Sandbox-deferred items (where Verification target is `sandbox repo`
     or `both` and the change can't be exercised from the PR branch) are
     marked `⏭️ sandbox-deferred — see Phase 2` per ADR-016. Judge
     enforces this mapping at diff-gate. -->

### Risks / out-of-scope

<Anything load-bearing the change touches (workflows, rules, role files,
migrations, public API). Anything explicitly NOT being addressed in this
PR. Write "None" or "N/A — <reason>" for sections that don't apply —
explicit acknowledgment, not silent omission.>

### Opportunity notes

<Optional. Surface up to 3 out-of-scope improvement opportunities
you noticed during planning (toil patterns, stale docs, adjacent
risks). Each note uses the 9-field shape defined in
`.context/rules/process_opportunity_feedback.md` § "Required fields
(9 total)". Cap is ≤3 per session per agent. Omit this section or
write "None" if nothing to surface; do not fold opportunities into
the plan scope.>
