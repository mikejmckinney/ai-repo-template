# Design Patterns — Code-Layer Reference (Lead / Index)

> **Purpose**: shared vocabulary for downstream code-layer reviews. Reviewers in projects derived from this template (CMMC enclave, Cloud Migration PoC, FedRAMP OSCAL, NIST 800-171, future forks) cite entries from this file and its sibling files by stable ID (`CP1`–`CP34`, `CAP1`–`CAP2`, `CCP1`–`CCP8`, `CDP1`–`CDP14`, `CIP1`–`CIP11`) when flagging a code-level pattern or anti-pattern. The orchestration layer of *this* template uses `.context/rules/repo_orchestration_patterns.md` (`P1`–`P9`, `AP1`–`AP8`) for the same purpose. The two surfaces are complementary, not overlapping.
>
> **Scope**: code-layer patterns for downstream projects derived from this template — application code, libraries, services, infrastructure-as-code constructs. NOT the orchestration / multi-agent / governance layer of this template (that lives in [`repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md)).
>
> **Status**: advisory. Critic cites entries as `CRAFT NOTES`; Judge does NOT block at diff-gate on a citation from this file. Tightening any entry to block-on-sight requires an ADR. See [ADR-020 §"Block-vs-advisory designation"](../decisions/adr-020-orchestration-patterns-reference.md#block-vs-advisory-designation) for the parallel decision on the orchestration file — the same logic applies here (this file ships everything advisory by default; the orchestration file ships a per-entry mix).

## Read this first — descriptive vocabulary, not prescription

This guide is a vocabulary, not a rulebook. Recognizing a pattern in existing code is more valuable than forcing one into new code. Three commitments make this real:

1. **Citing a pattern is the start of a conversation, not the end of one.** A reviewer writing "this is becoming a God Object — see [`AP1`](../../.context/rules/repo_orchestration_patterns.md#ap1--god-object)" must say *which detection signals fired* and *what the code-layer remediation looks like for this case*. The pattern name is a handle; the argument is the work. Reviewers who cite pattern names without justification are doing the thing the [§"Goal Substitution"](#cap1--goal-substitution) entry warns against — substituting a deliverable (a citation) for the outcome (a clearer review). (`AP1` lives in the orchestration patterns file because God Object's clearest manifestation in this template is at the orchestration layer; downstream code-layer reviewers may cite it for the analogous code-layer failure mode until a `CAP<N>` entry is added here.)
2. **Novel designs beat named patterns when the named pattern doesn't fit.** If a code change is a better fit for an unnamed shape than for any pattern in this guide, the unnamed shape wins. This guide does not enumerate every good design. Calling out "this isn't in the guide, and it should be" is itself a useful review comment.
3. **Most GoF patterns are 1994 C++/Smalltalk workarounds for missing language features.** In Python, JavaScript, Go, or any modern language with first-class functions and dynamic dispatch, several patterns collapse to a function or a decorator. Don't write Java-style ceremony when the language gives you the shape for free. Affected entries flag this explicitly.

The biggest active risk for this guide is **prescriptive drift** — reviewers learning to cite patterns as rules ("you should add a Repository here") rather than as vocabulary ("this is doing what Repository does, and that's why X"). If this guide ever earns the reputation of being a checklist, it has failed. Catch it early; flag it in PR review when it happens.

## Why this guide exists (dogfood-demand provenance)

This guide is itself a dogfood deliverable. The orchestration-layer counterpart ([`repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md)) was added under epic [#251](https://github.com/mikejmckinney/ai-repo-template/issues/251) after a sequence of structural refactors (sub-issues 1–4) repeatedly required reviewers and authors to argue patterns and anti-patterns in vague terms — the absence of named handles was visible cost. The same shape of cost is already starting to appear in downstream code projects bootstrapped from this template, two of which generated [`postmortem-001`](../postmortems/postmortem-001-workflow-bypass.md) and [`postmortem-002`](../postmortems/postmortem-002-poc-outcome-mismatch.md). The lessons in those postmortems generalize cleanly to the code layer; the entries in [§"Anti-patterns generalized from this template's postmortems"](#anti-patterns-generalized-from-this-templates-postmortems) below carry them across.

Demand here is read inclusively: this template's own dogfooding *counts as demand* for downstream projects, because patterns named here propagate through every fork. Waiting for a downstream PR review to cite a missing handle before adding the handle is a slower feedback loop than carrying lessons forward proactively from existing postmortems.

## How to use this file

- **Authors**: scan the relevant section of the appropriate file (lead / GoF / post-GoF / concurrency / data / integration) before writing a non-trivial new component. The goal is recognition, not selection — if a named pattern matches what you're already doing, use the standard form rather than reinventing one. If nothing matches, that's fine; don't force a fit.
- **Reviewers**: when flagging a structural concern, cite by ID (`CP<N>`, `CAP<N>`, `CCP<N>`, `CDP<N>`, or `CIP<N>`) and quote the specific detection signal that fired. Citing without quoting is review noise — the patterns are vocabulary, not authority.
- **Contributors**: when responding to a citation, you can rebut. "This looks like `CAP1` Goal Substitution but actually the user outcome is in [link]" is a valid response and ends the thread.

## How the files split

These files share one citation surface without sharing one numeric namespace. The lead file (this one) holds the framing, the postmortem-derived entries, and the index table below. Sibling files hold the GoF, post-GoF, concurrency, data / persistence, and integration / messaging catalogs respectively. This split exists because a single 700+ line catalog would itself match `AP1` (God Object) in the orchestration patterns file — see [ADR-021](../decisions/adr-021-agents-md-decomposition.md) for the parallel decomposition decision on `AGENTS.md`.

| ID range | File | Topic |
|---|---|---|
| `CAP1`–`CAP2`, `CP1` | this file ([`design-patterns.md`](design-patterns.md)) | Anti-patterns generalized from this template's postmortems, plus one positive pattern |
| `CP2`–`CP24` | [`design-patterns-gof.md`](design-patterns-gof.md) | The 23 Gang of Four patterns (Creational / Structural / Behavioral) |
| `CP25`–`CP34` | [`design-patterns-post-gof.md`](design-patterns-post-gof.md) | Post-GoF patterns (Repository, DI, MVC family, CQRS, Event Sourcing, Saga, Circuit Breaker, Bulkhead, Sidecar) |
| `CCP1`–`CCP8` | [`design-patterns-concurrency.md`](design-patterns-concurrency.md) | Concurrency control and scheduling patterns (queues, pools, deferred results, coordination primitives, shared-state access) |
| `CDP1`–`CDP14` | [`design-patterns-data.md`](design-patterns-data.md) | Data / persistence patterns (caches, read models, locking, auditability, snapshots, pools, idempotency, outbox) |
| `CIP1`–`CIP11` | [`design-patterns-integration.md`](design-patterns-integration.md) | Integration / messaging patterns (channels, routing, translators, splitters, aggregators, claim checks, DLQs, receiver dedupe, correlation, envelopes) |

Cite from any file by ID alone — the prefix and range tell the reader which file to open. Anchors are stable: `design-patterns.md#cap1--goal-substitution`, `design-patterns-gof.md#cp22--strategy`, `design-patterns-concurrency.md#ccp5--semaphore`, `design-patterns-data.md#cdp14--transactional-outbox`, `design-patterns-integration.md#cip9--idempotent-receiver`, etc. Renumbering would break citations across downstream PRs and is treated as a breaking change.

## Caveats

1. **The list isn't exhaustive.** Functional (Functor, Monad, Lens, Reader) and frontend-specific (Hooks, Container/Presenter, Compound Components) patterns still sit outside it. Concurrency now has a live sibling catalog at [`design-patterns-concurrency.md`](design-patterns-concurrency.md), but Actor, Reactor, and structured concurrency stay there as external pointers rather than internal IDs; cite an external authority for those instead of inventing a local handle.
2. **GoF reflects 1994 constraints.** Singleton, Visitor, and Interpreter are particularly likely to be anti-patterns today. Use the per-entry "When NOT" notes in [`design-patterns-gof.md`](design-patterns-gof.md) before reaching for them.
3. **Language matters.** Iterator, Strategy, Command, Observer, and Template Method are mostly language features in modern languages. The per-entry notes flag this where it applies.
4. **No backing ADR.** This guide is Docs-owned and advisory. Adding new patterns needs a Docs PR; tightening an entry to block-on-sight needs an ADR (because that changes the Critic/Judge contract). New entries go into the appropriate namespace without renumbering existing IDs; postmortem-derived entries use the next available `CAP<N>` / `CP<N>` number, concurrency entries use `CCP<N>`, data / persistence entries use `CDP<N>`, and integration / messaging entries use `CIP<N>`.

---

## Anti-patterns generalized from this template's postmortems

These are the highest-leverage entries in this guide. Each is an orchestration-layer lesson translated to the code layer — the postmortems documented an *orchestration-layer* incident, but the underlying failure mode applies just as cleanly to code. Each entry links back to (a) the originating postmortem and (b) the orchestration-layer counterpart in [`repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md), so a reader who wants the full provenance can trace the lesson end-to-end.

Important framing: the originating incidents were *not* code-layer bugs. The entries below are the code-layer *analog* of the orchestration-layer pattern, not a re-derivation from a code-layer postmortem.

### CAP1 — Goal Substitution

**Generalized from**: [PM-002](../postmortems/postmortem-002-poc-outcome-mismatch.md) ("Prompts 1–6 produced architecture instead of working demo"). Orchestration-layer counterpart: [`AP4` in `repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md#ap4--goal-substitution).

**Code-layer description**: a feature is defined as a list of artifacts (endpoints, classes, files, tables) and the implementation produces exactly those, satisfying the spec but missing what the user actually needed to do. The architectural equivalent of building all the requested files but never enabling the workflow they were supposed to support. APIs that match the IDL but can't be composed into the user journey. Database schemas that store the requested fields but make the canonical query path expensive. Microservices split by the lines named in the design doc instead of the lines that match real call patterns.

**Detection signals**:

- The PR description's "what shipped" list reads as nouns (entities, endpoints, files) without a single verb describing what a user can now *do*.
- The user-facing test plan asserts artifact existence ("`POST /users` returns 201") without asserting end-to-end behavior ("a new user can sign up, see their dashboard, and edit their profile").
- A downstream consumer asks "OK but how do I…?" and the answer requires composing 3+ artifacts the implementer never composed themselves.
- The acceptance criteria are checkbox-shaped — each box names a deliverable, not an outcome.

**When NOT to flag**: pure refactors with no user-visible change correctly assert artifact-shaped invariants and don't owe a user-outcome story; infrastructure groundwork for a multi-PR feature naturally ships artifact-shaped milestones.

**Code-layer remediation**: rewrite the user outcome in DO-language ("a user can…"), then walk the PR end-to-end against it; if any step requires combining artifacts the PR doesn't combine, the PR is incomplete. If the outcome can't be expressed in DO-language, escalate — the work isn't ready.

### CAP2 — Implicit Contract

**Generalized from**: [PM-001](../postmortems/postmortem-001-workflow-bypass.md) ("Workflow bypass on Phases 2–7"). Orchestration-layer counterpart: [`AP3` in `repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md#ap3--implicit-contract).

**Code-layer description**: a load-bearing precondition exists only in the author's head, not in the type system, in a runtime check, in a test, or in documentation that a future maintainer will encounter. The function works when called correctly; "called correctly" is unwritten. Common code-layer manifestations: undocumented invariants on input ranges, runtime checks that should be type checks, "this works as long as you call `init()` first," ordering dependencies between mutator calls, mutex acquisition order that prevents deadlock only if you remember which one to grab first, configuration values that must agree across two files but aren't validated to.

**Detection signals**:

- A function's docstring or signature does not state a precondition that must hold for the function to behave correctly.
- A bug report's root-cause line is "the caller did X but should have done Y first" — and there's no compile-time, runtime, or test-time check that catches X-without-Y.
- Two configuration values must agree (a port number in two services, a magic string in code and YAML, a key length in client and server) and there's no test asserting the agreement.
- A reviewer asks "what guarantees this is true here?" and the answer is "the caller is supposed to ensure that."

**When NOT to flag**: documented invariants enforced by adjacent type guards or assertions; preconditions deliberately checked once at a system boundary (input validation layer) and trusted thereafter; performance-sensitive hot paths where a documented contract is cheaper than a runtime check (note the trade-off in code).

**Code-layer remediation**: lift the precondition into the type system if the language supports it (newtypes, refinement types, builder patterns that enforce ordering, parameter wrappers); else into a runtime assertion at the function's entry; else into a test that exercises the calling sequence end-to-end; else into a docstring that the calling site can be expected to read. Pick the cheapest enforcement that survives a context shift.

### CP1 — Owner-Keyed Concurrent State

**Generalized from**: [PM-003](../postmortems/postmortem-003-active-md-merge-conflict.md) ("repo-local working-memory merge conflict between parallel agent PRs"). Orchestration-layer counterpart: [`P7` in `repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md#p7--owner-keyed-concurrent-state). This is a *positive* pattern — a recommended shape — not an anti-pattern. The corresponding anti-pattern is `AP6` Single-Writer Shared State in the orchestration file; the code-layer reverse of `CP1` is the absence of `CP1` where it was needed.

**Code-layer description**: when multiple writers share state, partition by an owner identifier (process ID, thread ID, request ID, tenant ID, region) with a multi-section schema rather than single-writer rewrite. Each writer owns its own section; readers merge. Direct application to multi-process, multi-thread, distributed, and multi-tenant code. Examples: per-tenant rows in a shared table keyed by `tenant_id`; per-shard counters in a key-value store rather than a single contended counter; per-region state files in S3 keyed by region prefix; per-worker queues that a coordinator drains rather than a single queue with N workers contending; per-connection state in a server rather than shared mutable state guarded by a global lock.

**When to use**: any situation where N writers can write concurrently and the system's correctness depends on no writer's update being silently overwritten by another. The cost is a small amount of indirection (one extra key in the schema) and the benefit is that writes commute — they can land in any order without conflict.

**When NOT to use**: genuinely-single-writer state (a configuration owned by one process); state where the most recent write should always win and history doesn't matter (cache entries, monitoring last-seen timestamps); systems with a hard latency budget where the indirection's overhead is measurable. Don't add owner-keying prophylactically — the cost is small but real, and removing it later is harder than adding it.

**Worked example**: this template's former repo-local working-memory file used a schema that placed each task in a `## Task: <branch-name>` section keyed by the branch name; agents wrote only their own section; three-way merge across parallel branches commuted because no two writers touched the same lines. Pre-[ADR-018](../decisions/adr-018-multi-task-active-md-schema.md), that file used a single-writer rewrite schema and produced the conflict that triggered PM-003.

---

## Cross-references

- [`design-patterns-gof.md`](design-patterns-gof.md) — sibling file, GoF entries `CP2`–`CP24`.
- [`design-patterns-post-gof.md`](design-patterns-post-gof.md) — sibling file, post-GoF entries `CP25`–`CP34`.
- [`design-patterns-concurrency.md`](design-patterns-concurrency.md) — sibling file, concurrency entries `CCP1`–`CCP8`; Actor, Reactor, and structured concurrency remain pointer-only there.
- [`design-patterns-data.md`](design-patterns-data.md) — sibling file, data / persistence entries `CDP1`–`CDP14`.
- [`design-patterns-integration.md`](design-patterns-integration.md) — sibling file, integration / messaging entries `CIP1`–`CIP11`.
- [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md) — orchestration-layer patterns (`P1`–`P9`, `AP1`–`AP8`) for *this* template, not for downstream code projects. The two files are complementary; reviewers cite from one or the other depending on what layer the change touches.
- [`.context/rules/domain_code_quality.md`](../../.context/rules/domain_code_quality.md) — code-layer Hard/Soft rules (`H1`–`H8`, `S1`–`S6`). Patterns here parallel those rules at a higher level of abstraction; rules say "do this," patterns say "this is what we call this shape."
- [`docs/postmortems/README.md`](../postmortems/README.md) — index of postmortems, including the three (PM-001, PM-002, PM-003) that the entries above generalize from.
- [`docs/decisions/adr-020-orchestration-patterns-reference.md`](../decisions/adr-020-orchestration-patterns-reference.md) — ADR ratifying the orchestration-layer patterns file; this file is the parallel code-layer addition under sub-issue 5 of parent epic #251.
