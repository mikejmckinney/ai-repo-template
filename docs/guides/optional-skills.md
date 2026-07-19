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
