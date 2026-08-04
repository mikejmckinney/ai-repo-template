# OpenCode Termination Diagnostics

Use this procedure when an interactive OpenCode session unexpectedly disconnects
or the server log reports `disposing all instances`. Historical sender identity
cannot be reconstructed when signal or host auditing was not active.

## Capture A Reproduction

Run OpenCode through the repository wrapper:

```bash
scripts/diagnose-opencode-session.sh
```

Set `OPENCODE_DIAG_DIR` to retain the lifecycle record at a known path. The
wrapper records its PID, the OpenCode PID and parent, start/end timestamps, exit
status, interpreted signal, executable name, cgroup memory counters, DB/WAL/SHM
sizes, periodic RSS and anonymous/file PSS, and peak memory. It does not record
arguments, prompts, session content, or model output.

Set `OPENCODE_DB_PATH` when the database is not at
`~/.local/share/opencode/opencode.db`. `OPENCODE_SAMPLE_INTERVAL` controls the
memory sample interval in seconds and defaults to `1`. The diagnostic directory
contains `database.before`, `database.after`, `memory.samples`, and
`memory.summary` in addition to the lifecycle files.

Interpret conventional shell exit statuses as follows:

| Status | Meaning |
|---|---|
| `0` | Normal process exit |
| `130` | `SIGINT` |
| `137` | `SIGKILL`; inspect cgroup and host OOM records |
| `143` | `SIGTERM` |

A model output limit should appear as a model completion/validation event while
the OpenCode process remains alive. It does not by itself explain server-wide
instance disposal.

High anonymous PSS with comparatively low file PSS indicates application
allocations rather than the SQLite file being mapped wholesale. Compare cold
start with opening the largest historical session before attributing the growth
to startup event replay or projected message rendering.

## Archive A Bloated Database

The archive utility is side-effect free unless `--apply` is supplied:

```bash
scripts/archive-opencode-database.sh
```

Review the database path, destination, and DB/WAL/SHM byte counts. Before apply:

1. Exit every OpenCode process, including background servers.
2. Ensure `sqlite3`, `fuser`, `jq`, and `sha256sum` are installed.
3. Ensure free space is at least the combined DB/WAL/SHM size.
4. Prefer durable off-Codespace storage for the resulting archive.

Run apply from a separate terminal after OpenCode has exited:

```bash
scripts/archive-opencode-database.sh --apply
```

Apply refuses files reported in use. It creates a coherent `restorable.db`,
requires `PRAGMA integrity_check` to return `ok`, compares session/message/part
counts, records a SHA-256 manifest, and only then moves the original DB/WAL/SHM
to `raw/`. It leaves the active database path absent so the next stock OpenCode
start creates a fresh generation. It never deletes or rewrites event rows.

Archive directories contain session data and must be protected like the active
database. Copy the verified archive off-host before deleting a Codespace.

## Roll Back Without Losing New Sessions

Do not restore an old database over a newer generation. First stop OpenCode and
archive the current generation to a different destination:

```bash
scripts/archive-opencode-database.sh \
  --apply \
  --archive-dir "$HOME/.local/share/opencode/archive/pre-rollback-$(date -u +%Y%m%dT%H%M%SZ)"
```

With the active path now absent, copy the selected coherent backup into place
and verify it before starting OpenCode:

```bash
cp "/path/to/older-archive/restorable.db" \
  "$HOME/.local/share/opencode/opencode.db"
sqlite3 "$HOME/.local/share/opencode/opencode.db" 'PRAGMA integrity_check;'
```

This switches generations; it does not merge sessions created in each one.
Retain both archives until the desired generation has been verified.

## Distinguish Incomplete Model Streams

Provider HTTP success and process exit zero do not prove a complete model turn.
OpenCode 1.17.20 can record `finish=unknown` after streaming reasoning without a
final answer. Correlate provider timestamps with the session's final assistant
finish reason, text parts, and token usage.

Fusion injects an exact final-line completion marker into panel prompts. Missing
markers preserve the rejected output and trigger fallback; do not replace this
with a character-count heuristic. A rejected panel establishes incomplete
output, not whether the provider, router, transport, or client caused it.

## Correlate Logs

Compare the lifecycle timestamp with:

- `~/.local/share/opencode/log/opencode.log`
- the current directory under `~/.vscode-remote/data/logs/`
- `/sys/fs/cgroup/memory.events`
- host or Codespaces lifecycle events available to the operator

MCP initialization warnings after a restart are not evidence that an MCP caused
the preceding shutdown. Reproduce once with optional MCP servers disabled, then
re-enable them individually if the termination stops.

## Identify A Signal Sender

The wrapper identifies the received signal but not the sending process. On a
host where the operator has tracing privileges, capture the kernel
`signal:signal_generate` tracepoint with `perf`, `bpftrace`, or the platform's
equivalent and filter for the recorded OpenCode PID. Preserve the sender PID,
command, target PID, signal, and timestamp.

If tracing is unavailable and logs contain only graceful disposal followed by a
new process, report the cause as `unknown external lifecycle restart`. Do not
classify it as OOM, MCP failure, output-limit completion, or user cancellation
without matching evidence.
