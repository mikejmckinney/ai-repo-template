# Repository Orientation

## Current State

1. Read `AI_REPO_GUIDE.md` and `.context/00_INDEX.md` when present.
2. Read the assigned issue, linked PR, latest `agent-state:v1` comment, and
   labels when a durable task exists.
3. Inspect `git status` and recent commits.
4. Run `scripts/verify-env.sh` when available.
5. Read `.context/sessions/latest_summary.md` only as historical guidance.

## Targeted Exploration

Use search rather than linear reading to identify:

- top-level directories and responsibilities;
- application, library, API, and CLI entry points;
- test frameworks and test locations;
- build, lint, format, and type-check configuration;
- CI workflows and deployment surfaces;
- architecture decisions and project-specific hard rules.

Verify commands from authoritative manifests before running or documenting
them. Missing optional files should be reported, not invented.

## Stability

Stable means the worktree contains only expected changes, environment checks
do not report onboarding blockers, and required orientation sources were read.
Otherwise name the exact unstable condition.
