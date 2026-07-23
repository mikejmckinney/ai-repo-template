<!--
Implementation Plan template (#164).

New issue templates include the block below in the issue body. Before writing
implementation code, fill it in and edit only between its v2 delimiters. For an
untemplated new issue, append the block once. Existing issues with a canonical
`implementation-plan:v1` comment are grandfathered and remain comment-based.

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

When the plan changes, fetch the current issue body, preserve everything outside
the delimiters byte-for-byte, merge the new current state into the block, and
append one bounded entry to `Revision history`. Re-fetch after writing and verify
requester-owned content survived. Do not post separate plan-revision comments.

Copy the canonical issue URL into the PR's `## Plan` section and refresh
the current summary whenever the plan changes. Link addressable GitHub resources
on first mention rather than writing bare issue, PR, commit, branch, run, ADR, or
repository-file references.
-->

<!-- implementation-plan:v2:begin -->

## 📋 Implementation Plan

**Issue:** #<number>

### Outcome

<One sentence. What user-observable change ships when this is merged?>

### Approach

<Two-to-five sentences. The strategy you chose and one alternative you
considered with why it was rejected. If the approach is obvious from the
issue, write "Direct implementation per issue.">

### Files to change

- [`README.md`](../blob/main/README.md) — <one phrase: what change>
- [`scripts/tests/`](../tree/main/scripts/tests) — <one phrase: what change>

<!-- Replace the examples and list every file or directory you expect to touch.
Existing files and directories must be clickable: use ../blob/main/<path> for a
file and ../tree/main/<path> for a directory. For a planned new path, link its
nearest existing parent and label the new path in the description. For a glob,
link its containing directory and keep the glob in the link text or description.
If the actual diff exceeds this list by more than ~30%, post a revised plan
before pushing. -->

### User outcome validation plan — PRIMARY

**Issue problem statement:** <one-sentence summary>

**User outcome / 15-minute test to perform:**

1. <step from issue>
2. <step from issue>
3. <step from issue>

**Material claim evidence to capture in PR:**

```text
Material claim:
Environment:
Why representative:
Implementation SHA:
Action performed:
Expected result:
Observed result:
Artifact:
Artifact type:
Redaction:
Retention:
Evidence reuse:
Result: pass | fail | blocked
```

<!-- Repeat the record for each material claim. Use the least costly
     outcome-equivalent environment and attach an inspectable artifact.
     External-state and runtime claims cannot be prose-only. Mixed changes may
     require multiple environments. See docs/guides/outcome-validation.md. -->

**Pass condition:**

- <what proves the problem statement is resolved>

**Failure / framing-disconnect condition:**

- <what would prove the implementation or issue framing is wrong>

<!-- This is the PRIMARY validation gate. The supporting verification
     section below covers regression/hygiene evidence (./test.sh, lint,
     CI, schema checks, sandbox runs). A green CI run with no
     user-outcome evidence is not ready for review. See
     `AGENTS.md` § Testing and validation. -->

### Supporting verification

**Change class**: <code-or-docs | pull_request-triggered workflow | default-branch-only workflow | mixed>
**Outcome environments**: <PR branch, sibling GitHub sandbox, fresh Codespace, fresh repository, provider preview, disposable infrastructure, etc.>

<!-- Pick the most-restrictive class your diff touches. The classifier in
     `scripts/verify-pr.sh` will compare your declaration against the
     actual changed paths and flag mismatches. It is the canonical trigger
     classifier; `docs/guides/agent-pipeline.md` explains the resulting
     verification classes without duplicating its trigger rules.
     Select environments with `docs/guides/outcome-validation.md`.
     Default-branch-only GitHub behavior uses the sibling repository adapter
     in `docs/guides/sandbox-verification.md` (ADR-016/ADR-034). -->

<How a reviewer can prove this works. Specific commands, specific assertions,
specific test names. "Tests pass" is not sufficient — name them.>

<!-- Each command listed here must have a matching result entry in the
     PR's `## Supporting verification results` section before the PR enters review.
     Environment-deferred items that cannot run from the PR branch are marked
     `⏭️ environment-deferred — <adapter + reason>`. Reviewers enforce this
     mapping and inspect the captured outcome artifacts. -->

### Risks / out-of-scope

<Anything load-bearing the change touches (workflows, rules, role files,
migrations, public API). Anything explicitly NOT being addressed in this
PR. Write "None" or "N/A — <reason>" for sections that don't apply —
explicit acknowledgment, not silent omission.>

### Opportunity notes

<Optional. Surface up to 3 out-of-scope improvement opportunities
you noticed during planning (toil patterns, stale docs, adjacent
risks). Each note uses the eight-field shape defined in
`AGENTS.md` § "Opportunity feedback". Cap is ≤3 per session per agent. Omit this section or
write "None" if nothing to surface; do not fold opportunities into
the plan scope.>

### Revision history

- YYYY-MM-DD: Initial plan.

<!-- implementation-plan:v2:end -->
