# FAQ

Frequently asked questions about the `ai-repo-template`. Answers link to deeper documentation where it already exists — this file is a navigator, not a duplicate.

> **For derived projects**: replace or extend this FAQ with questions specific to your project. Template-specific entries below (prefixed with "Template:") can be removed.

---

## Repo structure

### Template: Why does this repo have `README.md`, `AGENTS.md`, and `AI_REPO_GUIDE.md`?

Each targets a different audience or loader:

- `README.md` — humans reading on GitHub.
- `AGENTS.md` — root instructions most AI tools auto-load (Copilot, Cursor, Gemini).
- `AI_REPO_GUIDE.md` — token-optimized agent reference.

Full rationale and a comparison table live in [`docs/guides/context-files-explained.md`](guides/context-files-explained.md) and [`docs/decisions/adr-001-context-pack-structure.md`](decisions/adr-001-context-pack-structure.md).

### Template: What's the difference between `docs/` and `.context/`?

- `docs/` — human-facing reference (guides, ADRs, research). Verbose, explanatory.
- `.context/` — agent-facing canonical truth (rules, state, roadmap, vision). Lazy-loaded.

Decision record: [`docs/decisions/adr-001-context-pack-structure.md`](decisions/adr-001-context-pack-structure.md).

### Template: What agent execution model does the repository use?

One monolithic agent implements routine work. CI and lint are blocking;
agents normally apply `ai-review:live` for parallel advisory snapshots; daily and
weekly workflows perform recurring review; and the OpenCode `multi-model-consensus`
skill is the sole opt-in multi-model mechanism. See ADR-031.

---

## Using the template

### Does advisory review block implementation or merge?

No. Agents normally apply `ai-review:live` to eligible task PRs, but continue
implementation without waiting. Before completion they independently verify any
arrived snapshot matching the current PR head. Missing, stale, running, or failed
feedback remains non-blocking; CI and maintainer decisions remain authoritative.

### How do I know whether I'm editing the template itself or a derived project?

Run the `repo-onboarding` classifier. Canonical template identity selects
`ai-repo-template`; a derived copy with explicit seed state selects
`template-seed`; and an onboarded or legacy derived repository selects
`complete`. See [the onboarding skill](../.agents/skills/repo-onboarding/SKILL.md).

### Must a derived repository replace retained template resources?

No. The lifecycle contract lives in `.context/onboarding-state.json`. During
`template-seed` onboarding, preserve useful resources and extend, replace, or
delete them only when current project evidence requires it.

### Template: Where should I file limitations or known issues I've hit?

If it's an agent-facing gotcha, add it to `AI_REPO_GUIDE.md § Gotchas / Known Issues`. If it's human-facing, add it to `README.md § Limitations`. If it's a decision-specific follow-up, add it to the relevant ADR's "Future Work" subsection.
