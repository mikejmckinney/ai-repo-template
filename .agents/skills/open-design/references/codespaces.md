# Open Design in Codespaces

Open Design uses two local services by default:

| Port | Service |
| --- | --- |
| `5173` | Studio web UI |
| `7456` | Daemon API |

Keep daemon port `7456` private. Forward Studio port `5173` before opening it in
an external browser tab; your laptop's `127.0.0.1` is not the Codespace.

## Start the daemon and UI

Use two terminals for clearer failures and more reliable startup.

Terminal 1, from the repository root:

```bash
bash scripts/open-design-mcp.sh --daemon-only
```

Wait until the daemon reports that it is listening on port `7456`.

Terminal 2, from `apps/web` in the Open Design checkout:

```bash
NODE_OPTIONS="--max-old-space-size=4096" \
  OD_DAEMON_PORT=7456 \
  PORT=5173 \
  pnpm dev
```

Wait for the first successful page request before opening the forwarded
`5173` URL. Keep both terminals running.

## Combined development launcher

The combined launcher is convenient when its web sidecar is stable:

```bash
NODE_OPTIONS="--max-old-space-size=4096" \
  pnpm tools-dev run web --daemon-port 7456 --web-port 5173
```

If the daemon starts but the Studio never becomes ready, use the two-terminal
workflow. See [`troubleshooting.md`](troubleshooting.md) for health checks,
stale runtime cleanup, and logs.

The MCP launcher starts the same loopback-only daemon on demand. It rejects a
non-loopback `OPEN_DESIGN_DAEMON_URL` rather than exposing the local control
plane.
