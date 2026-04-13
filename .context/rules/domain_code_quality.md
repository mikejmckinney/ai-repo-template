# Domain: Code Quality

> **Purpose**: This file is the template's built-in, language-neutral quality floor — SOLID, TDD, and clean-code constraints that apply to every stack. Downstream projects may extend it with stack-specific rules (see "How to extend" below); they should not lower it without an ADR.
>
> **Scope**: constraints and tradeoffs, not formatter preferences. Style (tabs/spaces, quote type, max line length) belongs in `.pre-commit-config.yaml.template` or your project's linter config, not here.

## Hard Rules (Never Violate)

Hard rules block diff-gate. If you relax one, the Architect writes an ADR under `docs/decisions/` recording the tradeoff and Judge references it during review.

### H1 — Single Responsibility
Every function, class, and module has **one reason to change**. If you can describe a unit with "and" ("parses input **and** writes to the database"), split it. Flag any unit where two unrelated reasons to change live in the same file.

### H2 — Open / Closed
Extend behavior by adding new code, not by mutating stable interfaces. Any breaking change to a published interface, exported type, or public API requires an ADR plus a migration note for downstream callers.

### H3 — Liskov Substitution
Subtypes must honor their base contract. Do not narrow preconditions or widen postconditions in an override. If a subtype can't honor the contract, it's not a subtype — compose instead of inherit.

### H4 — Interface Segregation
Callers must not be forced to depend on methods they don't use. Split fat interfaces into role-specific ones. "One method per caller concern" is the floor, not the ceiling.

### H5 — Dependency Inversion
High-level modules depend on abstractions, not concrete low-level modules. Inject dependencies; don't `new` them inside business logic. Concrete wiring lives at the composition root (main / entry point).

### H6 — TDD Discipline
Write a failing test **before** implementation. Keep the red-green-refactor loop explicit. See `AGENTS.md` → "Testing requirements" for the test pyramid and CI expectations — this file does not duplicate them.

### H7 — No Dead Code
Unreachable branches, unused exports, commented-out blocks, and speculative helpers ship zero value. Delete them before merge. If you think you'll need something "soon," open a task instead of leaving a stub.

### H8 — No Silent Error Swallowing
Every `catch` / `rescue` / `recover` block must either rethrow with context, log with enough detail to diagnose, or convert to a handled result that the caller can act on. Empty catch blocks and bare `except: pass` fail diff-gate.

## Soft Rules (Prefer Unless Justified)

Soft rules are targets. Judge does not block on them; Critic flags them as `CRAFT NOTES` or `NITS`. A justified exception in the commit message is enough.

### S1 — Function Length
Target: a function fits on one screen without scrolling. The exact line count is stack-specific — set a threshold in the "How to extend" block below. Rationale matters more than the count: if a longer function is genuinely more readable than its split form, keep it and say why in a comment.

> Default threshold: `TEMPLATE_PLACEHOLDER` lines. (Suggested starting point: 40 for typed languages, 25 for dynamic languages.)

### S2 — Complexity and Nesting
Target: cyclomatic complexity and nesting depth stay low enough that a reader can hold the control flow in their head. When you feel yourself indenting a fourth level, extract.

> Default thresholds: cyclomatic complexity `TEMPLATE_PLACEHOLDER`, max nesting depth `TEMPLATE_PLACEHOLDER`.

### S3 — Names Describe Intent
Names say **what the code is for**, not **how it works**. Prefer `calculateRenewalDate` over `addThirtyDays`. Avoid abbreviations unless the abbreviation is a term of art in your domain — and if it is, capture it in a glossary.

### S4 — Comments Explain Why
Comments say **why**, not **what**. If the code already says what it does, a comment that restates it is noise — delete it. Use comments to record non-obvious tradeoffs, links to issues, and decisions the reader can't reconstruct from the code.

### S5 — Duplication Beats the Wrong Abstraction
Two similar blocks are cheaper than a premature abstraction. Three is a signal to extract — but only if the three genuinely share a reason to change (see H1). Rushing to DRY fuses code that should diverge.

### S6 — Test Pyramid
Many unit tests, fewer integration tests, minimal E2E tests. Concrete CI commands and coverage expectations live in `AGENTS.md` → "Testing requirements" and the project's own `README.md`.

## Role Enforcement Matrix

| Role | Enforcement behavior |
|---|---|
| **Architect** | Writes an ADR when a Hard rule is deliberately relaxed. Updates this file when adding stack-specific rules. Owns `.context/rules/**` per `agent_ownership.md`. |
| **Frontend / Backend** | Obey Hard rules. Justify Soft-rule exceptions in commit messages. Don't silently lower thresholds. |
| **QA** | Enforces via tests. Flags untested branches of Hard-rule code during the hand-off to Judge. |
| **Critic** | Flags subjective violations under `CRAFT NOTES` / `NITS`. Cites the rule ID (H1–H8, S1–S6) so the author can look it up. |
| **Judge** | Blocks diff-gate on unjustified Hard-rule violations. Treats Soft-rule notes from Critic as advisory input, not a block condition. |
| **PM** | Records rule-exception tasks in `.context/state/coordination.md` when resolving a violation requires a cross-role fix. |

## Exceptions Process

1. Reference the rule ID (e.g. `H2`, `S1`) in the PR description.
2. Explain why the exception is justified and what the alternative would cost.
3. Either cover the exception with a test that pins the new behavior, or record the tradeoff in an ADR under `docs/decisions/`.
4. Judge confirms the exception is documented before approving the diff.

## How to Extend for Your Stack

Downstream projects replace the `TEMPLATE_PLACEHOLDER` values and may add stack-specific rules. Keep extensions **additive** — do not delete Hard rules without an ADR.

```markdown
<!-- TEMPLATE_PLACEHOLDER: paste your stack-specific thresholds -->

## Stack-Specific Overrides

- S1 function length:     <N> lines (target), <N> lines (hard max)
- S2 cyclomatic complexity: <N> (target), <N> (hard max)
- S2 nesting depth:       <N> (target), <N> (hard max)
- Lint / format tool:     <tool + config path>
- Test framework:         <framework + command>
- Coverage target:        <percent> (changed files only)

## Stack-Specific Hard Rules (optional)

- <rule ID> <name>: <one-sentence rule>
```

## See Also

- `AGENTS.md` → "Testing requirements" — canonical TDD / test-pyramid / CI expectations.
- `docs/guides/agent-best-practices.md` → "The 200-Line Rule" and "Keep Individual Files Small" — file-size guardrails this rule file cross-references.
- `docs/guides/optional-skills.md` — SOLID Skills and everything-claude-code as opt-in external reinforcement for teams that want stricter enforcement.
- `.github/agents/judge.agent.md` — the diff-gate that blocks on Hard-rule violations.
- `.github/agents/critic.agent.md` — the subjective-quality reviewer that cites rule IDs from this file.
- `.context/rules/agent_ownership.md` — confirms Architect ownership of this file.
