---
description: Pre-push Critic + lint + test summary against the working-tree diff before pushing a non-trivial change.
agent: agent
---

# Pre-Push Review — Critic + Lint + Tests on Working-Tree Diff

> **Usage**: Run locally before `git push` on any non-trivial change.
> Produces a single Markdown summary with PASS / REQUEST_CHANGES per
> section. The implementer reads it and addresses anything before
> pushing.
>
> - **SHOULD** for any non-trivial diff (see AGENTS.md → "Work style").
> - **MUST** for the DevOps role on any change to `scripts/*.sh`,
>   `.github/workflows/*.yml`, or shell embedded in workflow `run:`
>   blocks (see `.agents/devops.md` Do list).
>
> **When to skip**: trivial diffs are exempt — i.e. ≤50 LOC changed
> AND no change to `scripts/*.sh`, `.github/workflows/*.yml`, role
> files (`.agents/*.md`, `.github/agents/*.agent.md`, `.claude/agents/*.md`), or
> `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md`. (Same
> non-trivial definition as AGENTS.md → "Work style".) Revert PRs and
> bot-authored PRs (Renovate, Dependabot) are also exempt. Phase 1's
> CI lint and the post-push bot-review loop still run.

This prompt is the local complement to `pr-resolve-all.md`. That prompt
covers *how* to fix bot findings after push; this prompt covers *what
to catch before* push so the bot loop has less to do.

## Inputs

- The current branch (HEAD).
- The base branch the PR will target (default `main`; override with
  `BASE_REF` env var when working off a feature branch).
- The working-tree diff: `git diff origin/<base>...HEAD` plus uncommitted
  changes (`git diff` and `git diff --cached`).

If the working tree has no changes vs. the base, report
`SKIPPED — no changes to review` and exit cleanly. This is not a
failure.

## Steps

Execute in order. Do not skip steps. Capture each step's pass/fail
into the Output template at the end.

### Step 1 — Diff scope

Resolve the base ref and capture the diff scope. The fetch is best-effort
(local-only repos and offline workflows must not crash here), but the
**resolved ref must exist** before the rest of the prompt continues —
otherwise `git diff origin/<base>...HEAD` would fail with a confusing
"unknown revision" message. Fall back to the local `<base>` ref and
emit a `SKIPPED — base ref not resolvable` line if neither is present.

```bash
BASE_REF="${BASE_REF:-main}"
git fetch origin "$BASE_REF" --quiet 2>/dev/null || true

if git rev-parse --verify --quiet "origin/${BASE_REF}" >/dev/null; then
  DIFF_RANGE="origin/${BASE_REF}...HEAD"
elif git rev-parse --verify --quiet "${BASE_REF}" >/dev/null; then
  DIFF_RANGE="${BASE_REF}...HEAD"
else
  # Per the prompt's Inputs section, SKIPPED is not a failure. Exit 0
  # so a local-only / offline repo (or one that legitimately doesn't
  # have the base ref yet) doesn't block the implementer's push.
  printf 'SKIPPED — base ref %s not resolvable (no origin/%s and no local %s)\n' \
    "$BASE_REF" "$BASE_REF" "$BASE_REF"
  exit 0
fi
```

Build three artifacts:

1. **Changed files** — `git diff --name-only "$DIFF_RANGE"` plus
   `git diff --name-only` (uncommitted) plus `git diff --name-only --cached`.
   Deduplicate.
2. **Unified diff** — `git diff "$DIFF_RANGE"` followed by `git diff` and
   `git diff --cached` (in that order). This is the input to Critic.
3. **Change class** — classify the diff into one or more of:
   - `shell` (any `scripts/*.sh`, `*.sh`, or shell within `run:` blocks)
   - `workflow` (any `.github/workflows/*.yml`)
   - `role-file` (any `.agents/*.md`, `.github/agents/*.agent.md`, or `.claude/agents/*.md`)
   - `agents-md` (`AGENTS.md`, `CLAUDE.md`, or `.github/copilot-instructions.md`)
   - `other`

The change class drives Step 3's lint scope and Step 4's test scope.

### Step 2 — Critic dispatch

Dispatch Critic against the unified diff with the **PRE-PUSH**
invocation surface (see `.agents/critic.md` →
"Repo Grounding"). Use the existing Critic checklist from that file.

Output format for this step is **lighter** than the diff-gate output:

- Only emit findings of severity **MAJOR CONCERN** or higher.
- Skip the `CRAFT NOTES` and `NITS` sections — those belong on the PR.
- Skip `QUESTIONS FOR AUTHOR` — there is no author/reviewer split here;
  if a question would be blocking, mark it as a `MAJOR CONCERN` with
  `unverified assumption` as the cause.
- Cite `path:line` for every finding (per AGENTS.md →
  "Critical thinking").

Result: `PASS` if zero MAJOR CONCERNS, otherwise `REQUEST_CHANGES`.

### Step 3 — Lint

Re-run Phase 1's lint suite (issue #229 PR #232) on the changed files
only — not the whole repo. The full repo runs in CI; this step is for
the local fast feedback loop.

```bash
# Shell files (only if change-class includes 'shell').
# Filter to actual shell scripts (*.sh) plus shebang-detected files
# under scripts/ — never the whole scripts/ tree (that would feed
# scripts/README.md into shellcheck/shfmt).
mapfile -t SHELL_FILES < <(
  printf '%s\n' "${CHANGED_FILES[@]}" \
    | while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        case "$f" in
          *.sh) printf '%s\n' "$f" ;;
          *)
            # Shebang-detected shell file (handles extension-less scripts).
            head -1 "$f" 2>/dev/null \
              | grep -qE '^#!.*\b(bash|sh)\b' && printf '%s\n' "$f"
            ;;
        esac
      done
)
[[ ${#SHELL_FILES[@]} -gt 0 ]] && {
  shellcheck --severity=warning "${SHELL_FILES[@]}"
  # Match CI flags from .github/workflows/lint-and-format.yml exactly
  # so a local PASS guarantees the CI shfmt step also passes.
  shfmt -d -i 2 -bn -ci "${SHELL_FILES[@]}"
  bash scripts/lint-shell-conventions.sh "${SHELL_FILES[@]}"
}

# Workflow files (only if change-class includes 'workflow')
mapfile -t WF_FILES < <(printf '%s\n' "${CHANGED_FILES[@]}" \
  | grep -E '^\.github/workflows/.*\.ya?ml$' || true)
[[ ${#WF_FILES[@]} -gt 0 ]] && {
  printf '%s\0' "${WF_FILES[@]}" | xargs -r -0 actionlint
}
```

If a tool is not installed locally, surface that as
`SKIPPED — <tool> not installed; CI will run it` rather than a
failure. The implementer can install per `AI_REPO_GUIDE.md`.

Result: `PASS` if every installed tool exits 0 and every required tool
ran (or was skipped with reason). Otherwise `REQUEST_CHANGES` with the
failing tool's output captured verbatim.

### Step 4 — Tests

Run `./test.sh`. This is non-negotiable — the file is fast (<10 s) and
covers the invariants the next agent in the pipeline will verify.

```bash
bash ./test.sh
```

If the change class includes `shell`, also run the bats fixture suite
(post-#280, the legacy `scripts/test-*.sh` delegates were removed and
the logic now lives directly inside the `.bats` files):

```bash
bats --jobs 4 scripts/tests/
```

Result: `PASS` if every test exits 0, otherwise `REQUEST_CHANGES` with
the failing assertion(s).

## Output template

Print exactly this Markdown block. Implementer reads it and either
fixes anything before push or proceeds.

```
## Pre-Push Review

**Branch**: <current-branch>
**Base**: <BASE_REF>
**Change class**: <comma-separated list>
**Files changed**: <count>

### 1. Critic — <PASS | REQUEST_CHANGES | SKIPPED>

<one-line TL;DR>

<MAJOR CONCERNS, if any, as bullets with path:line cites>

### 2. Lint — <PASS | REQUEST_CHANGES | SKIPPED>

- shellcheck: <PASS | FAIL: …  | SKIPPED — not installed | SKIPPED — no shell files>
- shfmt:      <…>
- lint-shell-conventions: <…>
- actionlint: <…>

### 3. Tests — <PASS | REQUEST_CHANGES>

- ./test.sh: <pass/fail counts>
- scripts/tests/*.bats (if shell): <list with pass/fail>

### Verdict

<PASS — safe to push | REQUEST_CHANGES — fix the items above first>
```

## Rules

- **Do not push if any section is `REQUEST_CHANGES`.** Fix locally
  first. The whole point of this prompt is to keep that work out of
  the bot-review loop.
- **Do not weaken or skip a tool because it surfaces a finding.** If a
  finding is wrong, fix the linter rule (or document the false
  positive in the report) — don't pre-emptively narrow the scope to
  pass.
- **Do not invoke this prompt as a pre-push git hook in v1.** A hook
  hides the report from the implementer's eyes and re-introduces the
  local-friction problem ADR-013 documents. The discipline is
  SHOULD/MUST in role files; the runnable prompt is the lever.
- **Don't promote `CRAFT NOTES` / `NITS` to MAJOR CONCERN** to force a
  re-think. If a craft issue is severe enough to block push, it is
  already a MAJOR CONCERN; if it isn't, defer it to PR review.

## Why this exists

Two recent PRs ran 8 and 11 review rounds (#228 and #225) before
landing. PR #228's mid-loop refactor introduced regressions that a
local Critic pass would have called out before push. Phase 1
(`lint-and-format.yml`) catches the static class; Phase 1.5
(`lint-shell-conventions.sh` + jq fixtures) catches the runtime-
semantics class; this prompt catches the subjective-quality class
locally before any bot ever sees the diff.
