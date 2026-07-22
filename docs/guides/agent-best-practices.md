# Agent Best Practices

## Default Shape

Use one implementing agent. Keep scope tied to the issue, work on a non-default
branch, preserve unrelated changes, and commit coherent boundaries. Do not create
role fan-out for routine implementation.

## Review

Run focused tests while editing and `./test.sh` before completion. CI and lint are
blocking. Apply `ai-review:live` to every eligible same-repository task PR and
continue implementation without waiting. Before completion, independently verify
findings from any arrived snapshot that matches the current PR head. Missing,
stale, running, or failed advisory feedback remains non-blocking. Daily and weekly
retro findings remain subject to normal verification before their draft fixes merge.

## Independent Perspectives

Use the OpenCode `multi-model-consensus` skill only when requested or when consequential
uncertainty remains after grounded analysis. Treat it as decision support, not a
replacement implementer.

## Context

Start with `AGENTS.md`, the assigned issue, and current code. Load ADR, benchmark,
workflow, or guide context only when the task intersects it. Prefer current live
state over archived transcripts.

## Evidence

Validate the user-observable outcome first. Record exact supporting commands,
sandbox links for default-branch-only behavior, and any failure or framing mismatch.
