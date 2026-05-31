# `.agents/` — canonical role definitions

This directory holds the **canonical, platform-agnostic role definitions** for
the 10 subagents in this repo's role-specialized pipeline (Analyst, Architect,
Backend, Critic, DevOps, Docs, Frontend, Judge, PM, QA).

Each `<role>.md` file is the single source of truth for that role's
responsibilities, Do/Don't list, output format, and handoff rules. Everything
that describes *what the role does* lives here.

## Relationship to platform overlays

Each AI platform that registers these roles as native subagents has its own
overlay folder, where each file is a thin **registration shim** containing
only platform-specific frontmatter (`name` casing, `tools` vocabulary, `model`
identifier) plus a one-line pointer back to the canonical file in this
directory.

| Platform | Overlay folder | File suffix | Loader |
|---|---|---|---|
| GitHub Copilot SDK custom-agent runtime | `.github/agents/` | `.agent.md` | reads frontmatter for dispatch routing; treats body as system prompt |
| Anthropic Claude Code native subagents | `.claude/agents/` | `.md` | reads frontmatter for dispatch routing; treats body as system prompt |
| (future) Cursor subagent registration | `.cursor/agents/` | `.md` | per #249 |

Adding a new platform is **not** a 10-file copy of role responsibilities —
it's 10 thin overlays, each pointing back to `.agents/<role>.md`.

## Edit discipline

- **Role responsibilities, output format, Do/Don't lists, handoff rules** →
  edit the canonical file at `.agents/<role>.md`.
- **Platform-specific tools vocabulary, model pin, name casing** → edit the
  matching overlay under `.<platform>/agents/`.
- **Description line (`description:` in frontmatter)** → keep byte-identical
  across canonical + every overlay. The parity check
  `scripts/checks/050-agent-mirror.sh` enforces this.

## Documentation-only frontmatter (canonical)

The canonical files carry two frontmatter keys that **no runtime currently
recognizes** — they exist as machine-readable documentation of the role's
intended scope and pipeline neighbors:

- `owned_paths:` — the file/glob patterns this role is allowed to write.
  Authoritative copy lives in
  [`.context/rules/agent_ownership.md`](../.context/rules/agent_ownership.md);
  the canonical frontmatter mirror is for at-a-glance reference only.
- `handoff_targets:` — the downstream roles this role typically dispatches to.

Both Claude Code and the Copilot SDK silently ignore unknown frontmatter
keys, so these are inert at load time. They are deliberately **not** mirrored
into the platform overlays.

## Role contract versioning (ADR-026)

Canonical role files carry a `role_contract_version:` integer. This
is the version a dispatched subagent reports in its `subagent_compliance`
block, and it belongs only to `.agents/<role>.md` because the canonical file is
where role bootstrap rules, output formats, handoff behavior, and compliance
return contracts live.

Do **not** add `overlay_version` to v1 role or platform files. Platform
overlays under `.github/agents/` and `.claude/agents/` are registration shims;
they own platform fields (`name`, `tools`, `model`, Copilot `handoffs`) but do
not own the role compliance contract.

Bump `role_contract_version` only when a canonical role's bootstrap, output
format, handoff behavior, or compliance return contract changes. Ordinary
responsibility wording, examples, or typo fixes do not require a bump unless
they alter what a dispatched role must emit or load.

Use [`_TEMPLATE.md`](_TEMPLATE.md) when adding or migrating a role contract.
It is a documentation template, not a canonical role, and parity checks must
not require platform overlays for it.

`_TEMPLATE.md` also carries the template-only metadata key
`agents_md_compat: <AGENTS_MD_VERSION>`. Replace the placeholder with the
current `AGENTS_MD_VERSION` only while drafting a concrete role contract that
needs that audit note; do not mirror it into platform overlays, and do not treat
it as a runtime dispatch key. Existing canonical role files rely on
`agents_md_version` in emitted compliance blocks for per-run startup evidence.

### Exact-output roles

Some roles have exact first-line output formats. Judge responses begin with
`DECISION:`; Critic responses begin with `CRITIC DECISION:`. ADR-026 preserves
those contracts: exact-output roles put receipt evidence in the trailing
`subagent_compliance` block instead of prepending a receipt line. Non-exact
roles may emit a visible `Role receipt v<N> — <role>` line, but the canonical
audit field remains `subagent_compliance.receipt`.

### Active handoff mapping (Copilot only)

The Copilot SDK custom-agent schema defines a native `handoffs:` field that
can dispatch one agent from another. The Copilot overlay at
`.github/agents/<role>.agent.md` maps `handoff_targets` (canonical) →
`handoffs:` (overlay) with `send: true` on each entry so handoffs would fire
**automatically** in any host that honors the field.

**Status in VS Code Copilot Chat (May 2026): inert.** Smoke tests on PR #292
verified the field loads cleanly into agent registrations (no schema
errors), but neither the `@mention` dispatch path nor the `runSubagent` tool
path actually fires the declared handoffs at subagent completion in this
surface. Even with `chat.subagents.allowInvocationsFromSubagents` enabled,
dispatched subagents are not given a dispatch tool, so they cannot fire the
handoff manually as a fallback either. The field is kept for forward
compatibility — a future Copilot SDK update or a different Copilot SDK host
(e.g. the standalone agent-builder CLI) is expected to honor it. **Until
then, handoff chaining in VS Code Copilot Chat is mediated by the default
agent**, which reads each dispatched subagent's canonical `handoff_targets:`
and calls `runSubagent` for the next role itself. See
[`.github/copilot-instructions.md`](../.github/copilot-instructions.md)
§ "Subagent dispatch (Copilot-specific)" for the default-agent protocol.

Two casing notes:

- Overlay handoff targets reference the overlay's `name:` field (Title-Case),
  not the canonical filename (lower-case). Example: the `pm` role has
  `name: Project Manager` in its overlay, so other roles' handoffs reference
  it as `target: Project Manager`.
- Claude Code has no equivalent field, so its overlays under `.claude/agents/`
  do not declare handoffs. Claude Code subagents hand off via the explicit
  `Task(subagent_type: '<role>')` tool call documented in
  [`CLAUDE.md`](../CLAUDE.md).

Keep the canonical `handoff_targets:` and the Copilot `handoffs:` list in
sync when changing pipeline neighbors. The parity check
`scripts/checks/050-agent-mirror.sh` does **not** currently enforce this —
it's a manual discipline.

## What's NOT in canonical

- Platform-specific `tools:` vocabulary (Copilot uses `'read'`, `'write'`, …;
  Claude Code uses `Read`, `Write`, `Grep`, `Glob`, `Bash`, `Task`, `WebFetch`).
- Platform-specific `model:` strings (Copilot uses qualified
  `'<Name> (copilot)'`; Claude Code uses Anthropic-only model IDs like
  `claude-opus-4-7`).
- Platform-conditional model-tier footers (e.g., the Copilot-only
  "subagent cost-tier ceiling" note that previously lived at the bottom of
  every `.github/agents/<role>.agent.md`).

## How parity is enforced

`scripts/checks/050-agent-mirror.sh` runs in `test.sh` and asserts, for each
role derived from `.agents/<role>.md`:

1. The matching overlay exists in every registered platform folder.
2. Each overlay's `description:` frontmatter line matches the canonical's
   `description:` line byte-for-byte.
3. Each overlay's `model:` line matches that platform's allowlist.
4. Each overlay body contains a string reference to `.agents/<role>.md`
   (catches accidental shim regression — overlays must not redefine
   responsibilities).

Adding `.cursor/` (or any future platform) to this check is a one-line array
edit + a per-platform allowlist constant.

## See also

- [`AGENTS.md`](../AGENTS.md) — universal rules and truth hierarchy.
- [`docs/decisions/adr-023-shared-subagent-canonical.md`](../docs/decisions/adr-023-shared-subagent-canonical.md) — rationale for the canonical/overlay split.
- [`docs/decisions/adr-003-claude-code-subagent-registration.md`](../docs/decisions/adr-003-claude-code-subagent-registration.md) — the original two-folder convention this ADR partially supersedes.
- [docs/guides/multi-agent-coordination.md](../docs/guides/multi-agent-coordination.md) — how the 10 roles hand off.
