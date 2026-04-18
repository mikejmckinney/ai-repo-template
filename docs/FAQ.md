# FAQ

Frequently asked questions about the `ai-repo-template`. Answers link to deeper documentation where it already exists — this file is a navigator, not a duplicate.

> **For derived projects**: replace or extend this FAQ with questions specific to your project. Template-specific entries below (prefixed with "Template:") can be removed.

---

## Repo structure

### Template: Why does this repo have `README.md`, `AGENTS.md`, `AI_REPO_GUIDE.md`, and `CLAUDE.md`?

Each targets a different audience or loader:

- `README.md` — humans reading on GitHub.
- `AGENTS.md` — root instructions most AI tools auto-load (Copilot, Cursor, Gemini).
- `AI_REPO_GUIDE.md` — token-optimized agent reference.
- `CLAUDE.md` — pointer file that Claude Code's native memory loader picks up; delegates to `AGENTS.md`.

Full rationale and a comparison table live in [`docs/guides/context-files-explained.md`](guides/context-files-explained.md) and [`docs/decisions/adr-001-context-pack-structure.md`](decisions/adr-001-context-pack-structure.md).

### Template: Why is `CLAUDE.md` at the repo root and not inside `.claude/`?

Both locations are valid — Claude Code auto-discovers either. Root is the `/init` default and keeps the file visible next to the other top-level docs. Moving it to `.claude/CLAUDE.md` is a preference, not a requirement. See the explanation inside [`CLAUDE.md`](../CLAUDE.md) itself.

### Template: What's the difference between `docs/` and `.context/`?

- `docs/` — human-facing reference (guides, ADRs, research). Verbose, explanatory.
- `.context/` — agent-facing canonical truth (rules, state, roadmap, vision). Lazy-loaded.

Decision record: [`docs/decisions/adr-001-context-pack-structure.md`](decisions/adr-001-context-pack-structure.md).

### Template: What's the difference between `.github/agents/` and `.claude/agents/`?

- `.github/agents/<role>.agent.md` — canonical role definitions. Read by GitHub Copilot's custom-agent runtime.
- `.claude/agents/<role>.md` — Claude Code native subagent registration. Points back to the canonical file.

`test.sh` enforces that the `description:` frontmatter stays byte-identical between the two so both loaders dispatch on the same intent. Decision record: [`docs/decisions/adr-003-claude-code-subagent-registration.md`](decisions/adr-003-claude-code-subagent-registration.md).

---

## Using the template

### Do I have to use multi-agent roles, or can I work solo?

Solo work is fine. The 10 roles (analyst, architect, judge, critic, pm, frontend, backend, qa, devops, docs) are helpful when multiple agents work in parallel without stepping on each other, but a single agent can wear any hat as needed. Full workflow: [`docs/guides/multi-agent-coordination.md`](guides/multi-agent-coordination.md).

### How do I know whether I'm editing the template itself or a derived project?

`AGENTS.md` has a template-detection block at the top. If the repo name is `ai-repo-template` (or the legacy `dotfiles`), the meta-docs are preserved. Otherwise, files containing `TEMPLATE_PLACEHOLDER` are treated as stubs to replace. See [`AGENTS.md`](../AGENTS.md) lines 3–12.

### What does `TEMPLATE_PLACEHOLDER` mean and how do I find every instance?

It's a marker used by this template to flag scaffolding that derived projects should replace. Run [`scripts/verify-env.sh`](../scripts/verify-env.sh) to check for the marker and report how many matches it finds.

### Why are there deployment templates for Vercel, Railway, and Render — do I need all three?

No. Pick one (or none). The templates in `config/` each have a `.template` suffix so nothing is active until you rename. See [`config/README.md`](../config/README.md) for the decision criteria per platform.

### Template: Where should I file limitations or known issues I've hit?

If it's an agent-facing gotcha, add it to `AI_REPO_GUIDE.md § Gotchas / Known Issues`. If it's human-facing, add it to `README.md § Limitations`. If it's a decision-specific follow-up, add it to the relevant ADR's "Future Work" subsection.
