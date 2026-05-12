# Clarification and ambiguity

> Extracted from AGENTS.md §"Clarification and ambiguity" in PR for #253 (ADR-021).
> Apply when the request is ambiguous or you'd otherwise have to invent facts to proceed.

When a request is genuinely ambiguous — where different reasonable interpretations lead to meaningfully different work — stop and ask before proceeding (unless it qualifies as a low-stakes decision — see the escape hatch below). Don't guess and build, and don't ask and build in parallel; ask, then wait.

- **Resolve from the repo first.** Before asking, check the **Truth hierarchy** sources (see `AGENTS.md` §"Truth hierarchy") for an existing answer. If you can resolve the ambiguity by reading, do that instead of asking.
- **verify details with live sources when available and cite sources**
- **When to trigger a clarifying question.** Ask specifically when: (1) the request could reasonably mean two or more different things, (2) a decision requires information only the user has (business context, preferences, external constraints), (3) the request conflicts with something in the repo's rules or prior decisions (follow the **Push back** rule in [`process_critical_thinking.md`](process_critical_thinking.md) rather than just asking), or (4) proceeding would require inventing facts (API shapes, data structures, domain terms) that can't be verified.
- **Don't ask** about style preferences, formatting, or conventions the repo's linter or rules files already answer.
