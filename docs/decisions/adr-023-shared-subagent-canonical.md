# ADR-023: Canonical role bodies live in `.agents/<role>.md`; vendor folders carry thin registration overlays

## Status

Accepted (supersedes part of [ADR-003](./adr-003-claude-code-subagent-registration.md); superseded in part by [ADR-026](./adr-026-compliance-contracts.md))

## Date

2026-05-09

## Context

ADR-003 stood up the two-registry design: GitHub Copilot's SDK custom-agent runtime reads `.github/agents/<role>.agent.md`, Claude Code's native subagent loader reads `.claude/agents/<role>.md`, and a parity check enforced byte-identity on the `description:` line. At the time, the practical solution was "author the canonical role body in the Copilot file and reduce the Claude file to a 43-line shim that delegates back."

Eight months and ~10 role files later, three problems with that arrangement surfaced:

1. **Vendor-folder lock-in for canonical content.** The "real" role bodies — responsibilities, Do/Don't lists, output formats — lived inside `.github/agents/`, a folder named after one specific vendor (GitHub) and one specific runtime (Copilot SDK). Anyone reading the file structure would reasonably conclude these definitions are Copilot-specific. They are not — they describe roles that are equally meaningful to Claude Code, future Cursor/Windsurf/Aider integrations, and human reviewers. Naming the canonical home after one platform is a structural smell (P4 vs AP2 in `.context/rules/repo_orchestration_patterns.md`).

2. **Vendor-specific frontmatter polluted the canonical body.** Each `.github/agents/<role>.agent.md` file carried `tools:` (with Copilot-specific tool names like `read`, `write`, `search`, `fetch`), `model:` (with Copilot's qualified format `'Claude Opus 4.7 (copilot)'`), and a footer `## Model tier note (ADR-019)` block that referenced the Copilot subagent ceiling limitation. None of those belong in a canonical role definition; they're all properties of *how* a specific runtime registers and dispatches the role.

3. **Adding a third platform meant duplicating the body again.** Issue #248 was opened anticipating Cursor support. Under ADR-003's arrangement, that meant either (a) generating per-platform files from a manifest (the P8 pattern — significant tooling investment) or (b) hand-copying the canonical body into a third vendor folder (compounding AP2 — Mirror Duplication). Neither was attractive. The conversation that produced this ADR rejected the manifest/generator path explicitly: it was overkill for low-change content where the per-platform divergence is mostly frontmatter.

The premise that "Claude is a 43-line shim, Copilot has the body" was correct as of the PR being reviewed. The premise that "this is the right long-term shape" was not.

## Decision

1. **Canonical role bodies live in `.agents/<role>.md`** — a platform-agnostic top-level directory. Each file contains:
   - Frontmatter: `name` (lowercase by convention), `description`, optional `owned_paths`, optional `handoff_targets`. **No `tools:`. No `model:`.** Both fields are properties of the platform registration, not of the role itself.
   - Body: full role responsibilities, Do/Don't list, output formats, escalation rules — everything that was previously inside `.github/agents/<role>.agent.md` minus the `## Model tier note (ADR-019)` footer (which was Copilot-specific).

2. **Vendor folders carry thin registration overlays** that point at the canonical:
   - `.github/agents/<role>.agent.md` — Copilot SDK overlay. Frontmatter only: `name` (Title-Case for Copilot's display convention), `description`, `tools` (Copilot's lowercase vocabulary), `model` (Copilot's qualified format with the `(copilot)` suffix, or omitted for Low-tier roles per ADR-019). Body is a thin pointer to the canonical role body in `.agents/<role>.md` (a short blockquote naming the canonical path plus a brief "See also" footer; not paraphrased role responsibilities).
   - `.claude/agents/<role>.md` — Claude Code overlay. Frontmatter only: `name` (kebab-case for Claude Code's `Task(subagent_type:)` convention), `description`, `tools` (Claude Code's PascalCase vocabulary), `model` (Anthropic-only strings: `inherit`, `claude-opus-4-7`, etc.). Body is a thin pointer (same shape as the Copilot overlay above).

3. **Overlays are hand-maintained, not generated.** No script regenerates `.github/agents/` or `.claude/agents/` from `.agents/`. The per-platform divergence (tool vocabulary, model string format, name casing) is small enough and stable enough that a generator would be solving a problem we don't have.

4. **N-way parity is enforced by `scripts/checks/050-agent-mirror.sh`**, which performs four checks per role per platform:
   - The overlay file exists.
   - The overlay's `description:` line matches the canonical's `description:` byte-for-byte.
   - The overlay's `model:` value satisfies the platform's allowlist (Copilot allows the qualified format or absence; Claude Code requires one of the Anthropic strings).
   - The overlay body contains a literal reference to the canonical file path (`.agents/<role>.md`).

   Adding a new platform means appending one row to each parallel array in the check (`platforms`, `overlay_dirs`, `overlay_suffixes`, `model_allowlist_res`, `model_required_flags`) and writing one overlay per role.

## Consequences

**Positive**:

- The canonical role definition is no longer trapped inside a vendor folder. `.agents/<role>.md` is what a new contributor or new platform integrator should read.
- Vendor-specific concerns (tool vocabulary, model string format) live exclusively inside vendor folders, where they belong.
- The Mirror Duplication anti-pattern (AP2) is resolved at the body level. Only the `description:` line is parity-enforced across platforms — and that's a single line per role, which the script catches at PR time.
- Adding a third platform (Cursor, Aider, Windsurf, etc.) requires one overlay file per role pointing at the same canonical, plus one row in the parity check's parallel arrays. No body duplication, no generator.
- The collapsed overlays are small enough (~18 lines each) that they're easy to read end-to-end. A reviewer can verify "yes, this overlay registers role X for platform Y" without scrolling.

**Negative**:

- One more file per role to maintain (10 canonical + 20 overlays = 30 files, vs the previous 20). The overlays are tiny, but they exist.
- The doc-trigger lockstep row in `.context/rules/process_doc_maintenance.md` now lists three role files (canonical + two overlays) instead of two, which is more to remember when adding/removing/re-scoping a role.
- The N-way parity check is structurally more complex than the previous two-file byte-identity check. The parallel-arrays shape was chosen specifically because the more obvious packed-string shape (`IFS='|' read`) collided with the regex `|` characters in the model allowlists.

**Neutral**:

- The two-registry design from ADR-003 is preserved — both vendor folders still exist and both auto-dispatch on `description:`. ADR-003 is superseded *in part*: the registry shape and Copilot-vs-Claude split are unchanged; only the "Claude is a shim that points to Copilot" claim is rewritten as "both are shims that point to `.agents/`."

## Alternatives considered

1. **Canonical YAML manifest with generated per-platform files (P8).** Initial plan posted on issue #248 included a Python generator + per-platform JSON mappings + a stale-overlay CI gate. Rejected by user mid-implementation: the generator was solving a problem (multi-target proliferation) that doesn't exist at our current platform count, and the maintenance cost of the generator + mapping files was higher than the cost of hand-maintained 18-line overlays. The P8 caveat in `.context/rules/repo_orchestration_patterns.md` was updated to call this out: "this pattern earns its keep when the canonical content has 3+ surfaces *and* the per-surface differences are large enough that hand-maintained overlays would be lossy."

2. **Keep canonical in `.github/agents/`; just update the parity check to enforce body-references-canonical from `.claude/agents/`.** Rejected because it doesn't solve problem 1 (vendor-folder lock-in) or problem 2 (vendor-specific frontmatter polluting the canonical). It just papers over the smell.

3. **Move canonical to `.context/agents/`.** Rejected because `.context/` is for project-canonical *truth artifacts* (rules, state, roadmap, vision) per ADR-001, not for role definitions that downstream consumers (the dispatchers) need to read alongside their platform overlays. Top-level `.agents/` is more discoverable and avoids implying that role files are part of the lazy-loaded context pack.

## References

- [ADR-003](./adr-003-claude-code-subagent-registration.md) — original two-registry design (this ADR supersedes its "Claude shim points to Copilot canonical" claim)
- [ADR-019](./adr-019-per-role-model-tiering.md) — per-role model tiering (the `model:` field this ADR moves from canonical to overlays is governed by ADR-019)
- [ADR-020](./adr-020-orchestration-patterns-reference.md) — orchestration patterns vocabulary (P4 Adapter, P8 Manifest, AP2 Mirror Duplication — all referenced in Context above)
- Issue [#248](https://github.com/mikejmckinney/ai-repo-template/issues/248) — original issue, includes Pre-Flight Report (Analyst HOLD verdict surfaced premise correction) and Plan + Plan revision comments
- `.agents/README.md` — operational guide for editing canonical and overlays, parity check enforcement, and adding new platforms
- `scripts/checks/050-agent-mirror.sh` — the N-way parity check
