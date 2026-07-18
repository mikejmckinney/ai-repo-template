# Open Design in Codespaces

Open Design uses two local services by default:

| Port | Service |
| --- | --- |
| `5173` | Studio web UI |
| `7456` | Daemon API |

Forward both ports in the Codespaces **Ports** tab before starting either
service. Open the Studio through the forwarded `5173` URL in an external
browser tab, not through your laptop's `127.0.0.1`.

## Start the daemon and UI

Use two terminals for clearer failures and more reliable startup.

Terminal 1, from the Open Design checkout:

```bash
pnpm exec od daemon start --headless --port 7456 --no-open
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
