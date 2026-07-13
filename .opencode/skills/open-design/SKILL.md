---
name: open-design
description: |
  Orchestrate the Open Design (OD) MCP server for design generation.
  Use when the user asks to generate, render, edit, or inspect a design:
  landing pages, dashboards, decks, mobile screens, brand images, or motion
  graphics. Also use for "the design I have open", design systems, and
  "what designs do I have". Do not trigger for application-code changes or
  copy-only edits to an existing artifact.
---

# Open Design

MCP tool descriptions are the source of truth for parameters and return
values. This skill defines call order, clarification points, and recovery.

## Before using MCP

- For installation and MCP configuration, read
  [`references/setup.md`](references/setup.md).
- In Codespaces, read [`references/codespaces.md`](references/codespaces.md).
- For runtime failures, read
  [`references/troubleshooting.md`](references/troubleshooting.md).
- Restart OpenCode after changing the skill or MCP configuration.

## Resolve the request

1. Ask for platform, audience, tone, scale, constraints, and brand only when
   the answer changes the design. Do not repeat details the user supplied.
2. For `PPT`, `deck`, `slides`, `presentation`, `document`, or `PDF`, ask
   whether the user wants browser-viewable HTML/SVG or a binary export before
   starting. Open Design does not produce binary office files directly.
3. If the user names an agent, call `list_agents` and use only a returned ID.
4. If the user names a skill, verify it with `list_skills`.
5. To discover design systems, call `list_mcp_resources`, then read the exact
   returned `od://design-systems/<id>/DESIGN.md` URI with
   `read_mcp_resource`. Design-system discovery uses MCP resources rather than
   a dedicated catalog tool.

## Generate or refine

1. Use the active project when the user refers to the design they have open.
   Call `get_active_context` only when the active project or file must be
   confirmed explicitly.
2. Create a project before the first generation when no project exists. Bind
   a selected design system or skill at project creation when appropriate.
3. Call `start_run` with a focused prompt. Serialize runs that target the same
   project because they share a working directory.
4. Poll `get_run` every 30-60 seconds. A running status with unchanged file
   times normally means the inner agent is still working. Do not cancel unless
   the user asks.
5. On success, return `previewUrl` as a clickable Markdown link. If no
   `previewUrl` is present, return `agentMessage`.
6. Pull generated work with `get_artifact(project)` rather than a chain of
   `get_file` calls. Pass the project explicitly after a run.
7. Refine with another `start_run` on the same project so project context and
   design tokens remain consistent.

## Read and edit artifacts

- Prefer `get_artifact` for an entry file and its referenced siblings.
- Use `get_file` for one known file and page through an `od:file-window`
  marker with `offset`.
- Use `create_artifact` only for a new artifact entry. It rejects an existing
  target.
- Use `write_file` to iterate on an existing file.
- Confirm an irreversible project deletion, then call
  `delete_project(project, confirm: true)`.

## Quality checks

Before presenting generated work, reject invented metrics, placeholder copy,
emoji feature icons, generic purple-blue gradients, default indigo accents,
and repetitive card grids. Verify responsive behavior, source-backed brand
tokens, and the requested content and interaction states.

## Recovery rules

- If active context is unavailable, ask the user to activate the project in
  Open Design.
- If a run fails, report its error and preserve any returned partial result;
  retry only with a narrower prompt or after fixing the reported cause.
- If `create_artifact` reports an existing target, use `write_file`.
- If the daemon is unreachable or MCP tools are missing after configuration,
  use the troubleshooting reference and restart OpenCode.
