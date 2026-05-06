# ADR-017: Template repo installs pre-commit shellcheck + actionlint by default (template-only; ADR-013 unchanged for derived repos)

## Status

Accepted

## Date

2026-05-05

## Context

Issue #229 documents the PR-iteration cost driving this decision: PR #228
ran 8 rounds (5 mechanically preventable; 2 self-inflicted by an in-fix
refactor) and PR #225 ran 11 rounds (workflow-verifiability gap, owned
separately by issue #227). Phase 1 (PR #232) shipped the CI-side
shellcheck + actionlint job in `.github/workflows/lint-and-format.yml`.
Phase 1.5 (PR #238) shipped the runtime-semantics gate
(`scripts/lint-shell-conventions.sh` + jq fixture extraction).

CI catches these classes only after the contributor has pushed — every
fix-and-push round still costs maintainer attention and bot rounds. The
remaining lever is *local* enforcement before the push: a pre-commit
hook running the same shellcheck and actionlint checks against the
working tree.

ADR-013 already considered installing pre-commit hooks by default for
derived repos and decided **not** to: pre-commit requires a Python
runtime, derived repos vary in stack, and the existing
`.pre-commit-config.yaml.template` works as opt-in scaffolding for
those that want it. ADR-013's rationale for derived repos has not
changed and is not revisited here.

What *has* changed is the evidence base for the **template repo's own
development**. The PR-iteration cost is template-internal pain, not
derived-repo pain. The template's contributors are working in a fully
provisioned dev container (Python + Go + Node already present), so the
"derived repos may not have Python" objection from ADR-013 does not
apply to template-internal commits. Installing the hooks for the
template's own development closes the local-enforcement gap without
imposing anything new on derived repos.

## Decision

**Install `.pre-commit-config.yaml` at the repo root with shellcheck +
actionlint hooks for this template repo only.** Derived repos continue
to receive `.pre-commit-config.yaml.template` (the heavyweight scaffold)
and continue to opt in per ADR-013.

Concretely:

1. Promote a *minimal* `.pre-commit-config.yaml` (shellcheck + actionlint
   only — no detect-secrets, commitizen, large-file checks, etc.) to
   the repo root. The hook flags are kept in sync with
   `.github/workflows/lint-and-format.yml`. A clean `pre-commit run --all-files`
   is a strong signal CI will pass for these tools (note: shellcheck is
   installed via apt in CI without a version pin, so exact version parity
   is not guaranteed — only flag and severity parity).
2. Keep `.pre-commit-config.yaml.template` intact as the heavyweight
   scaffold for derived repos. Add a top-of-file comment cross-linking
   ADR-017 so derived-repo contributors understand the divergence.
3. **Do not modify ADR-013.** Its decision (no install by default
   *for derived repos*) is preserved verbatim. ADR-017 is *additive* to
   ADR-013, not a supersession — see "Non-reversal of ADR-013" below.

## Options Considered

### Option 1: Install minimal `.pre-commit-config.yaml` for template only (chosen)

- **Pros**: Closes the local-enforcement gap without imposing anything
  on derived repos. Hook flags are kept in sync with CI; a clean local
  run is a strong signal CI will pass for these tools. Reversible: delete the file.
- **Cons**: Template contributors must `pre-commit install` once after
  cloning. Heavy users running `git commit --no-verify` defeat the
  guardrail (mitigation: this is the same escape hatch every pre-commit
  setup has; misuse shows up in PR review).

### Option 2: Install the full heavyweight `.pre-commit-config.yaml.template` for template too

- **Pros**: Single config story. Template contributors get
  detect-secrets, commitizen, etc. for free.
- **Cons**: Drags in heavyweight dependencies (`detect-secrets`,
  `commitizen`) the template doesn't otherwise need. Slows every local
  commit. Conflates "what the template ships as scaffolding" with "what
  the template uses internally" — exactly the conflation ADR-017 wants
  to avoid.

### Option 3: Reverse ADR-013 entirely (install for both template and derived repos)

- **Pros**: Single rule, no special-casing.
- **Cons**: Re-imposes the Python-runtime objection on every derived
  repo. ADR-013's decision was made in writing on evidence specific to
  derived repos; reversing it without that evidence changing is a
  process violation. Out of scope here.

### Option 4: Do nothing; rely on CI feedback only

- **Pros**: Zero additional setup.
- **Cons**: Leaves the local-enforcement gap that this issue exists to
  close. The PR-iteration cost evidence is documented and pointing to
  this lever specifically.

## Consequences

### Positive

- Template contributors catch shellcheck and actionlint failures before
  pushing, eliminating the simplest class of bot-review round.
- Hook flags are kept in sync with CI (actionlint version is pinned;
  shellcheck is installed via apt in CI without a version pin). A passing
  `pre-commit run --all-files` is a strong signal CI will pass for these tools.
- Derived repos see no change. ADR-013's contract is preserved.
- The `.pre-commit-config.yaml` ↔ `.template` divergence is documented
  in both files and in this ADR; cross-links make the two-track design
  legible to future contributors.

### Negative

- Template contributors must run `pre-commit install` once after
  cloning. The README and AI_REPO_GUIDE.md document this step.
- `--no-verify` defeats the guardrail. This is inherent to pre-commit;
  AGENTS.md §"Work style" already names `--no-verify` as a discouraged
  shortcut, and reviewers can spot its misuse in `git log`.
- Two pre-commit configs now coexist in the repo (`.pre-commit-config.yaml`
  for template-internal use; `.pre-commit-config.yaml.template` for
  derived repos). Mitigation: each file's header comment names its
  audience.
- Derived repos created from this template inherit `.pre-commit-config.yaml`.
  A maintainer who runs `pre-commit install` without reading the header will
  activate the minimal 2-hook config rather than the heavyweight
  `.pre-commit-config.yaml.template` scaffold. Mitigation: the
  `.pre-commit-config.yaml` header now contains an explicit `DELETE IT`
  instruction for derived-repo maintainers. Onboarding guides should surface
  this step alongside the `pre-commit install` instruction.

### Neutral

- This ADR does not add hooks for shfmt or markdownlint. Those checks
  are CI-only for now; promote later if PR-iteration data shows them
  needed.

## Non-reversal of ADR-013

ADR-013's decision is **not reversed**. ADR-013 governs *derived repos*
and concluded "do not install by default" on the strength of three
arguments: (a) Python-runtime dependency, (b) heavyweight template
config, (c) reversibility if a future incident demands it. None of
those arguments change here:

- (a) The Python-runtime dependency still applies to derived repos;
  ADR-017 does not install anything on them.
- (b) The heavyweight template config (`.pre-commit-config.yaml.template`)
  is preserved unchanged. ADR-017 ships a *separate* minimal config for
  template-internal use.
- (c) The reversibility argument is preserved: a future postmortem
  could still trigger ADR-013 to flip without reopening this ADR.

ADR-017 is therefore **additive**, not superseding. ADR-013 retains
`Status: Accepted`. Both ADRs coexist; the index in
`docs/decisions/README.md` lists them as parallel decisions on adjacent
slices of the same problem.

## Verification

- [ ] **V1**: `.pre-commit-config.yaml` exists at the repo root and
  contains exactly two hook repos (shellcheck + actionlint) with
  versions matching `.github/workflows/lint-and-format.yml`.
- [ ] **V2**: `.pre-commit-config.yaml.template` is unchanged in
  substance (same hooks, same versions) and now carries a top-of-file
  comment pointing to this ADR.
- [ ] **V3**: ADR-013's `Status` line still reads `Accepted` (no
  supersession marker).
- [ ] **V4**: `bash test.sh` passes the new invariants validating V1–V3.
- [ ] **V5**: `pre-commit install && pre-commit run --all-files` runs
  cleanly on `main` (or surfaces a small triage list documented in the
  PR body).

## References

- Source incident analysis: issue #229
- Sibling decision: `docs/decisions/adr-013-pre-commit-on-main-default.md`
  (governs derived repos; preserved verbatim)
- Phase 1 implementation: PR #232 (CI shellcheck + actionlint job)
- Phase 1.5 implementation: PR #238 (runtime-semantics gate)
- Template config consumed by derived repos: `.pre-commit-config.yaml.template`
- External: <https://pre-commit.com/>
