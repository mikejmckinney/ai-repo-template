# PR Issue Resolution — Systematic Verify-and-Fix

> **Usage**: Post one of these as a PR comment:
>   - `@claude follow .github/prompts/pr-resolve-all.md`
>   - `@copilot follow .github/prompts/pr-resolve-all.md`
>
> Both agents will read this file and execute the Phase 1–3 procedure below.
> Claude is wired via `.github/workflows/claude.yml`'s `claude-mention` job.
> Copilot follows the `@copilot follow <path>` rule documented in
> `.github/copilot-instructions.md`.

---

You are resolving every open issue, suggestion, and TODO in this pull request. Your job is to find them all, verify each one, fix the valid ones, and produce a traceable audit trail. Do not guess — verify everything against the actual code.

> **How to run this prompt**: Read this entire file before starting. Execute
> Phase 1, then Phase 2, then Phase 3, in that order. Do not interleave or
> skip phases. If your cumulative response would exceed GitHub's per-comment
> size limit, post sequential `Part 1/N`, `Part 2/N`, … comments rather than
> truncating. Apply the Rules section to every phase.

## Phase 1: Build the Issue/Suggestion Index

Scan ALL of these sources for issues, suggestions, requested changes, and TODOs:

1. **PR description** — look for task lists, noted limitations, known issues, "TODO" or "FIXME" mentions.
2. **Review threads** — every unresolved review comment, including inline code comments and top-level review bodies. Pay attention to threads marked "Request changes."
3. **Commit messages** — scan for "TODO", "FIXME", "HACK", "WIP", or "known issue" language.
4. **Code diff** — scan the changed files for new `TODO`, `FIXME`, `HACK`, `XXX`, or `WORKAROUND` comments introduced in this PR.
5. **Linked issues** — if the PR description references GitHub issues (#NNN), read those issues for acceptance criteria that may not be fully met.
6. **CI/workflow failures** — if any checks failed, treat each distinct failure as an indexed item.

**For each item found, assign a sequential ID** (e.g., `ISS-01`, `ISS-02`, ...).

**If the PR has more than 10 items**: Post the index first as a comment before starting fixes. Wait for confirmation, then proceed in batches of 5. This prevents token exhaustion and lets the author course-correct early.

**If an item was already addressed** in a subsequent commit or resolved thread: mark it `✅ Already resolved` with a link to the resolving commit, and skip to the next item.

### Index Output Format

Post this as a PR comment before starting fixes:

```markdown
## Issue/Suggestion Index

| ID | Source | Summary | Status |
|----|--------|---------|--------|
| ISS-01 | [Review comment](link) | Missing null check on `user` param | 🔍 Pending |
| ISS-02 | [PR description](link) | TODO: add rate limiting | 🔍 Pending |
| ISS-03 | [Code comment](link) | FIXME in src/auth.ts:42 | 🔍 Pending |
| ISS-04 | [CI failure](link) | TypeScript build error | 🔍 Pending |
| ISS-05 | [Review comment](link) | Suggestion: extract helper fn | ✅ Already resolved in abc1234 |

**Total**: X items found, Y already resolved, Z to address.
Proceeding with fixes for remaining items.
```

## Phase 2: Verify, Fix, Validate Each Item

For each unresolved item, work through this sequence. Do not skip steps.

### Step 1 — Link
Provide a direct URL to where the issue was mentioned (review comment permalink, PR description section, file + line in the diff, or issue number).

### Step 2 — Verify
Confirm the issue actually exists in the current state of the branch. This means:
- For bugs/logic issues: read the relevant code and confirm the problem. If possible, describe a concrete scenario that would trigger it.
- For missing tests: confirm the behavior is untested by searching the test files.
- For style/refactor suggestions: confirm the code matches what the reviewer described.
- For CI failures: read the failure log and identify the root cause.
- If the issue is **not reproducible** (already fixed, reviewer was mistaken, or the code has changed): document why and mark it accordingly. Do not fabricate a fix for a non-issue.

### Step 3 — Fix
If the issue is valid, implement the fix:
- Make the smallest change that addresses the issue.
- Stay inside the files already touched by this PR when possible. If a fix requires changes to files outside the PR's scope, flag it and ask before proceeding.
- For refactor suggestions: apply only if the suggestion is clearly better. If it's a judgment call, implement it but note that the author may want to review.
- Include the exact file path and line numbers in your report.

### Step 4 — Validate
After each fix (or batch of fixes):
- Run the test suite. Report pass/fail counts.
- Run the linter. Report clean/error counts.
- Run the build/typecheck. Report success/failure.
- If the repo has an `AI_REPO_GUIDE.md`, use its commands as canonical. Otherwise, detect from `package.json`, `Makefile`, `pyproject.toml`, etc.
- If a verification command is not available or not applicable, say so explicitly rather than skipping silently.

### Step 5 — Status
Assign one of:
- `✅ Fixed` — issue was valid, fix implemented, verification passed.
- `✅ Already resolved` — issue was already addressed before this run.
- `⚠️ Needs clarification` — issue is ambiguous, or the right fix depends on a design decision the author should make. Describe what's unclear and suggest options.
- `⚠️ Partial fix` — fix addresses part of the issue but something remains. Explain what's left.
- `❌ Not reproducible` — the issue does not exist in the current code. Explain why.
- `❌ Out of scope` — fix requires changes to files/systems outside this PR. Describe what's needed so the author can file a follow-up.

## Phase 3: Resolution Report

After all items are processed, post a final summary comment:

```markdown
## Resolution Report

### Summary
- **Total items found**: X
- **Already resolved**: X
- **Fixed in this pass**: X
- **Needs clarification**: X
- **Not reproducible**: X
- **Out of scope**: X

### Verification
- Tests: ✅ X passed, ❌ X failed
- Lint: ✅ Clean / ❌ X errors
- Build: ✅ Success / ❌ Failed
- Typecheck: ✅ Clean / ❌ X errors

### Detail

---

#### ISS-01: Missing null check on `user` param
- **Source**: [Review comment](link)
- **Evidence**: `src/auth.ts:42` — `user` parameter is used without a null guard. If the session lookup returns null (expired session, deleted user), this throws an unhandled TypeError.
- **Fix**: Added null check with early return of 401 at `src/auth.ts:42-45`. Commit: `abc1234`.
- **Verification**: `npm test` — 47 passed, 0 failed. New test added in `tests/auth.test.ts:89`.
- **Status**: ✅ Fixed

---

#### ISS-02: TODO: add rate limiting
- **Source**: [PR description](link)
- **Evidence**: Confirmed — no rate limiting exists on the `/api/login` endpoint. The TODO in the PR description is a known deferred item.
- **Fix**: N/A — this is a follow-up item, not a bug in the current diff.
- **Verification**: N/A
- **Status**: ❌ Out of scope — recommend filing as a separate issue.

---

(continue for each item)
```

## Rules

- **Do not fabricate issues.** Only index things that are explicitly mentioned in the sources listed in Phase 1, or concrete problems you can verify in the code.
- **Do not make drive-by changes.** Fix only what's indexed. If you notice something else while working, note it at the bottom of the report under "Additional Observations" but do not fix it without asking.
- **Do not mark something fixed without verification.** Every `✅ Fixed` must have a passing test/lint/build result.
- **Preserve existing behavior.** Fixes should not change functionality beyond what's needed to resolve the indexed issue.
- **If you run out of context or token budget**: Post what you have so far with a clear "Batch 1 of N complete — proceeding with next batch" marker. Do not silently truncate.
- **If `AI_REPO_GUIDE.md` exists**, read it first for canonical test/lint/build commands and repo conventions.
