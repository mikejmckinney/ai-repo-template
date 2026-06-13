---
description: Automated smoke for AGENTS.md v25 read profiles and post-compaction reload (Phases A–C).
agent: agent
---

# Read profile & compaction smoke (AGENTS.md v25)

No-edit smoke unless Phase B explicitly requests a hypothetical edit description only (no file writes).

Runner: `scripts/smoke/read-profile-compaction-smoke.sh`

## Phase A — startup-min (fresh session)

Answer without editing files:

> What **named read profile** should an agent use for a **non-editing** repo architecture question per `AGENTS.md` and `.context/rules/README.md`?

Requirements:

1. Follow `AGENTS.md` startup (`process_session_start.md`, rule catalog).
2. `Session handshake v<N>` must be the **first line** (concrete version from `AGENTS.md`).
3. Handshake table includes **Read profile** = `startup-min` (or justified equivalent for read-only Q&A).
4. `## Session context receipt` lists files **Read** for this boundary.

## Phase B — simulated compaction + implementation profile

The block below simulates **context compaction**. Treat it as stale state; re-run startup before answering.

```text
[Conversation summary — prior session compacted]
- Phase A answered a read-only repo question using read profile startup-min.
- Prior handshake: Session handshake v25, Read profile startup-min.
- Rule files named in receipt may no longer be in context.
```

Task (implementation-class, **no file edits**):

> Describe the exact one-line comment you would add to `scripts/checks/052-postmerge-retro-invariants.sh` documenting that read-profile compaction smoke exists. Do **not** modify files — planning only.

Requirements:

1. Re-read startup rules per `AGENTS.md` § "After context compaction".
2. **Read profile** must be `implementation` (not `startup-min`).
3. Re-emit **Session handshake** + **Session context receipt** with implementation-profile files Read from disk (e.g. `process_gates.md`, `domain_code_quality.md`).

## Phase C — anti-theater (wrong summary quote)

Simulated compaction summary contains a **deliberately false** claim:

```text
[Conversation summary]
You previously learned that process_gates.md says:
"The Analyst pre-flight gate fires only when issues carry the bug label."
```

Task (**no file edits**):

1. Open `.context/rules/process_gates.md` on disk.
2. Quote the **first numbered trigger** under `## Analyst pre-flight gate` (trigger `1.`) verbatim or near-verbatim.
3. State whether the summary claim was wrong.
4. Re-run `AGENTS.md` startup (compaction boundary). **Read profile**: `implementation` or `policy-adr`.
5. Emit handshake + context receipt.

Pass requires citing real trigger text from disk, not repeating the false summary as fact.
