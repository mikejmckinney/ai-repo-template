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
status, interpreted signal, process metadata, and cgroup memory counters. It does
not record prompt or model output.

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
