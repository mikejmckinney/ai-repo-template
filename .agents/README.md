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
- [`docs/guides/multi-agent-coordination.md`](../docs/guides/multi-agent-coordination.md) — how the 10 roles hand off.
