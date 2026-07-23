# Optional Skills

Skills are optional, task-triggered capabilities. Install or invoke one only when
it solves a concrete problem without duplicating the repository's built-in workflow.

The repository's sole opt-in multi-model mechanism is
`.agents/skills/multi-model-consensus/`. Other bundled skills cover bounded concerns
such as session recovery, onboarding, browser tooling, and frontend guidance.

Review a skill's permissions, external services, generated files, and maintenance
cost before adoption. Skills do not create a role registry or change ADR-031's
monolithic implementation default.

Externally sourced skills are pinned and refreshed through the review-first
process in [Vendored Skill Supply Chain](skill-supply-chain.md). Cloud-provider
authentication and smoke-test boundaries are documented in
[Cloud Provider Tooling](cloud-provider-tooling.md).

## Codespaces profiles

Normal `install.sh` execution installs the `default` profile from
`.config/codespace-tools.json`. It includes local quality tools and the runtime
prerequisites of MCPs that are enabled in the generated development config:
checksum-verified Chrome for Testing, its declared Debian dependencies, and the
locked Open Design daemon checkout. It also installs the locked npm dependencies
under `.github/agent-runtime` that local quality tests and workflow helpers import.
Playwright and Chrome DevTools npm packages remain exact, on-demand MCP launcher
dependencies rather than global installs.

The default also installs OpenCode, Claude Code, Cursor Agent, and Codex because
current workflow development and verification use those CLIs. Exact npm packages are integrity-checked where the vendor
supports stable package versions. Cursor Agent and existing standalone Codex
installations remain vendor-managed channels; bootstrap verifies them without
overwriting their user-level launchers. Authentication is never embedded or
performed by bootstrap.

Use `bash install.sh --profile core` for the smaller quality/runtime-only set.
Explicit `--profile agents` preserves the default core-plus-agents union.

Verify the installed core without mutation:

```bash
scripts/install-codespace-tools.sh --profile core --verify-only
```
