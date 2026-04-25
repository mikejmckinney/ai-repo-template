# ADR-013: Pre-commit hook for `main` protection — not installed by default

## Status

Accepted

## Date

2026-04-25

## Context

`docs/postmortems/postmortem-001-workflow-bypass.md` lists "no pre-commit hook to block direct work on `main`" as contributing factor #2: the template ships `.pre-commit-config.yaml.template` but does not install it, so even an agent that *tried* to be careful had no mechanical guardrail backing the (then-implicit) "branch first" expectation.

Issue #180 carries an acceptance criterion to record a decision on this:

> **Pre-commit-on-main decision recorded** as either an installed hook + docs, or an ADR explaining why we don't install it by default.

Three options were on the table during PR-B planning:

1. **Install by default.** Promote `.pre-commit-config.yaml.template` to `.pre-commit-config.yaml`, add a hook that blocks direct commits to `main`, and wire `install.sh` to run `pre-commit install`.
2. **Hybrid.** Ship a minimal block-`main`-only `.pre-commit-config.yaml` (keep the heavyweight template intact), leave `pre-commit install` opt-in via a documented `install.sh` flag.
3. **Don't install by default; record the decision.** Keep `.pre-commit-config.yaml.template` as-is (opt-in for derived repos), and rely on AGENTS.md §"Work style" (per ADR-012) as the rule.

ADR-012 already shipped the explicit AGENTS.md branch-and-commit rule — the *load-bearing* fix for the same incident. ADR-012's "Consequences → Neutral" section explicitly flagged that a pre-commit hook would be a complementary mechanical guardrail and that the install-by-default decision would be made separately here.

## Decision

**Do not install a pre-commit hook by default.** The template continues to ship `.pre-commit-config.yaml.template` (the existing heavyweight config — `detect-secrets`, `commitizen`, `check-added-large-files`, etc.) as opt-in scaffolding. Derived repos that want hook-based `main` protection rename it to `.pre-commit-config.yaml`, install `pre-commit` for both the `pre-commit` and `commit-msg` stages (`pip install pre-commit && pre-commit install && pre-commit install --hook-type commit-msg`), and add a `no-commit-to-branch` hook configured for `main`. The `--hook-type commit-msg` step is required because the shipped template config uses `stages: [commit-msg]` for the `commitizen` hook; bare `pre-commit install` only registers the `pre-commit` stage and would leave commit-message linting silently disabled.

The AGENTS.md rule shipped in ADR-012 is the primary backstop. This ADR records that the mechanical guardrail is *available* but *opt-in*, with the rationale below.

## Consequences

**Positive:**

- No new tooling dependency lands in every derived repo. `pre-commit` requires Python + `pip`; not every repo built from this template has a Python runtime in scope.
- The existing `.pre-commit-config.yaml.template` stays a pure example. Derived repos already know to copy and customize it; we do not change that contract.
- The decision is reversible. If postmortem-002 or postmortem-003 traces another bypass to "branch rule was ignored," promoting the template to an installed default is a one-PR change.

**Negative:**

- A documented gap remains: an agent that ignores ADR-012's AGENTS.md rule can still commit directly to `main` with no friction. The template inherits this gap.
- "Opt-in" reliably means "most derived repos do not turn it on." The mechanical guardrail effectively does not exist for the population of repos this template generates.
- Re-evaluation requires either a follow-up postmortem or someone manually noticing the gap. There is no automated trigger to revisit the decision.

**Neutral:**

- The existing `.pre-commit-config.yaml.template` is heavyweight (commit-msg linting, secret detection, large-file checks). Adding a `no-commit-to-branch` hook to it is a one-line addition for any derived repo that opts in. We do not need to ship a separate minimal config to make the opt-in path easy.
- ADR-012 and this ADR together close the issue #180 acceptance criterion for "pre-commit-on-main decision recorded" without weakening the rule-text fix.

## Verification

- [x] **V1 (No silent un-tracking)**: `git ls-files | xargs -I{} git check-ignore {} 2>/dev/null` returned empty on commit `33fb5c3` — no currently-tracked file is matched by the new `.gitignore` patterns. Evidence: PR #188 description.
- [x] **V2 (`.env.example` negation)**: `git check-ignore -q .env.example` exited `1` (NOT ignored), confirming the `!.env.example` negation works.
- [x] **V3 (`.terraform/` is ignored)**: `git check-ignore -q .terraform/anything` exited `0` (matched), confirming the acceptance-criteria minimum pattern fires.
- [x] **V4 (template integrity)**: `bash test.sh` → 207 passed / 0 failed / 1 warning, matching the PR #187 baseline.

## Implementation checklist

- [x] Add default `.gitignore` at repo root (PR #188).
- [x] Header documents the "extend, don't replace" contract for derived repos and cites postmortem-001 + ADR-012/013.
- [x] Record this decision (ADR-013).
- [x] Add ADR-013 row to `docs/decisions/README.md` index.
- [ ] **Re-evaluation trigger** (manual): if a future postmortem traces another bypass to "the AGENTS.md rule was ignored," reopen this decision and promote `.pre-commit-config.yaml.template` to an installed default.

## References

- Source incident: `docs/postmortems/postmortem-001-workflow-bypass.md` (contributing factor #2)
- Tracking issue: #180 (PR-B)
- Sibling decision: `docs/decisions/adr-012-explicit-workflow-preconditions.md` (the AGENTS.md rule this ADR complements)
- Existing template config: `.pre-commit-config.yaml.template`
- External: <https://pre-commit.com/> (`no-commit-to-branch` hook lives in `pre-commit-hooks`)
