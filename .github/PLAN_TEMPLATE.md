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

If that revision happens after a PR is already open, update the PR body in
that same push cycle with a short `Revision history` note and a link to the
issue's plan-revision comment, so re-runs don't evaluate stale context.
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

### Verification

<How a reviewer can prove this works. Specific commands, specific assertions,
specific test names. "Tests pass" is not sufficient — name them.>

### Risks / out-of-scope

<Anything load-bearing the change touches (workflows, rules, role files,
migrations, public API). Anything explicitly NOT being addressed in this
PR. Write "None" or "N/A — <reason>" for sections that don't apply —
explicit acknowledgment, not silent omission.>
