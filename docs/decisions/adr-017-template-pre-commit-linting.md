# ADR-017: Template repo uses pre-commit linting (actionlint + shellcheck)

## Status

Accepted

## Date

2026-05-10

## Context

Issue #229 highlighted that relying solely on CI for linting results in an unsustainable number of PR iterations for trivial mechanical issues (actionlint and shellcheck failures). PRs #225 and #228 showed that 8–11 rounds were spent mostly on mechanical violations that could have been caught locally before pushing.

ADR-013 states that pre-commit hooks are *opt-in* for derived repos to avoid interrupting fast local workflows.

However, for the template repository itself, maintaining high code quality and reducing agent review cycles is paramount. We need a way to catch mechanical errors locally before push, without reversing the opt-in policy for derived repositories.

## Decision

We will install `.pre-commit-config.yaml` in the root of the template repository containing hooks for `shellcheck` and `actionlint`.

This decision changes only the *template repo's* pre-commit posture. Derived repos still opt-in per ADR-013. The reversal trigger in ADR-013 ("another bypass") doesn't apply; the new justification is PR-iteration cost in the template's own development.

## Consequences

*   **Template repo:** Developers modifying the template repository will have `shellcheck` and `actionlint` run automatically on `git commit`, catching mechanical errors early and reducing CI cycle iterations.
*   **Derived repos:** The `.pre-commit-config.yaml` is provided, but it is not automatically installed as a pre-commit hook during project initialization unless explicitly opted into by the maintainers of the derived repository (preserving ADR-013).
