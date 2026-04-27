---
description: "Instructions for onboarding this repository to GitHub Copilot."
type: "prompt"
agent: "agent"
---

# Copilot Repository Onboarding Prompt

Your task is to onboard this repository to GitHub Copilot by creating a `.github/copilot-instructions.md` file that helps AI coding agents work efficiently with this codebase.

> **Important**: This is a one-time setup task. Take your time to thoroughly explore the repository before writing instructions.

## Goals

- Reduce likelihood of AI-generated PRs getting rejected due to build failures or misbehavior
- Minimize bash command and build failures
- Allow the agent to complete tasks quickly by reducing exploration time

## Limitations

- Instructions must be ≤ 2 pages
- Instructions must not be task-specific (general guidance only)

---

## Phase 1: Explore the Repository

### Read Key Documentation
- [ ] `README.md`
- [ ] `CONTRIBUTING.md`
- [ ] `AI_REPO_GUIDE.md` (if it exists)
- [ ] Any other docs in `/docs` or similar

### Identify Build & Test Commands
Search for and document:
- [ ] Package manager files (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, etc.)
- [ ] Build scripts (`Makefile`, `build.sh`, etc.)
- [ ] CI/CD configs (`.github/workflows/`, `.circleci/`, etc.)
- [ ] Linting configs (`.eslintrc`, `.prettierrc`, `ruff.toml`, etc.)

### Map the Codebase
- [ ] Identify major directories and their purposes
- [ ] Find entry points (main files, CLI handlers, server bootstraps)
- [ ] Locate test directories and frameworks used
- [ ] Note any generated or vendor directories to avoid

---

## Phase 2: Validate Commands

For each command, actually run it and document:

### Bootstrap
```bash
# What command sets up the development environment?
# Example: npm install, pip install -e ., cargo build
```

### Build
```bash
# What command builds the project?
# Document any prerequisites or environment setup required
```

### Test
```bash
# What command runs tests?
# Note: Run the tests and document any setup required
```

### Lint
```bash
# What command runs linting/formatting checks?
```

### Common Issues
- Document any errors encountered during setup
- Document workarounds for common problems
- Note commands that are order-dependent

---

## Phase 3: Write copilot-instructions.md

Create `.github/copilot-instructions.md` with this structure:

````markdown
## Required Context

- Always read `/AI_REPO_GUIDE.md` first and follow it
- If `AI_REPO_GUIDE.md` conflicts with README, prefer the most recently updated source

## Project Overview

<1-2 sentences about what this project does>

### Tech Stack
- Language: <primary language>
- Framework: <if applicable>
- Build tool: <tool>
- Test framework: <framework>

## Quick Commands

### Setup
```bash
<setup command>
```

### Build
```bash
<build command>
```

### Test
```bash
<test command>
```

### Lint
```bash
<lint command>
```

## Project Structure

<List of key directories and their purposes>

## Key Files

| File | Purpose |
|------|---------|
| `<path>` | `<description>` |

## Conventions

- <Coding style conventions>
- <Naming conventions>
- <Commit message format>

## Common Gotchas

- <Things that commonly trip up developers>
- <Order-dependent commands>
- <Required environment variables>

## Before Submitting Changes

Always verify:
1. [ ] Tests pass: `<test command>`
2. [ ] Linting passes: `<lint command>`
3. [ ] Build succeeds: `<build command>`
````

---

## Verification

After creating the file:

1. [ ] Read the file as if you're a new AI agent
2. [ ] Run all documented commands to verify they work
3. [ ] Check that file paths referenced actually exist
4. [ ] Ensure no sensitive information is included

---

## Output

Provide:
1. The complete `.github/copilot-instructions.md` file
2. Summary of what you learned about the repository
3. Any issues or ambiguities you encountered
