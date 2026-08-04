# Open Design Troubleshooting

Run these commands from the Open Design checkout unless noted otherwise.

## Stale development runtime

`daemon did not expose status in time` commonly indicates stale state from a
previous `tools-dev` run:

```bash
pnpm tools-dev stop
rm -rf .tmp/tools-dev/default
pnpm tools-dev run web --daemon-port 7456 --web-port 5173
```

## Daemon health

Check the daemon directly:

```bash
curl --fail --silent --show-error \
  http://127.0.0.1:7456/api/health
```

If health fails, restart the daemon. If health succeeds but the Studio cannot
save or repeats onboarding, restart the web UI and hard-refresh the Studio.
In Codespaces, also confirm that both `5173` and `7456` were forwarded before
startup.

## Port already in use

Choose unused daemon and web ports, pass both to the launcher, and forward the
same values:

```bash
pnpm tools-dev run web --daemon-port 17456 --web-port 15173
```

For the two-terminal workflow, keep `OD_DAEMON_PORT` aligned with the daemon's
selected port and `PORT` aligned with the forwarded Studio port.

## Web sidecar exits

The combined launcher's web sidecar can exit during the first compile,
especially in constrained remote environments. If daemon health still
passes, leave the daemon running and start `apps/web` directly:

```bash
NODE_OPTIONS="--max-old-space-size=4096" \
  OD_DAEMON_PORT=7456 \
  PORT=5173 \
  pnpm dev
```

## Inspect status and logs

```bash
pnpm tools-dev check
pnpm tools-dev logs daemon
pnpm tools-dev logs web
```

If MCP tools remain unavailable after the daemon is healthy, rerun the
bootstrap's MCP dry-run, review the target client configuration, apply it if
needed, and restart OpenCode.

The repository launcher writes auto-start failures to
`${XDG_RUNTIME_DIR:-/tmp}/ai-repo-open-design/daemon.log`.

## Version mismatch

The bootstrap requires Node 24 and pnpm 10.33.2 because those are the engines
declared by the pinned Open Design release. In a Codespace, rerun
`scripts/install-codespace-tools.sh --profile core` for those prerequisites, or
`scripts/install-codespace-tools.sh --profile media` when FFmpeg is missing. Do
not bypass the version check with a newer pnpm major.

## HyperFrames browser or render failure

Run these from the repository root:

```bash
bash scripts/hyperframes.sh doctor
bash scripts/hyperframes.sh browser ensure
```

The wrapper sets `HYPERFRAMES_SKIP_SKILLS=1`; removing it lets `init` write
mutable global skill copies outside the repository lock. In a low shared-memory
Codespace, keep HyperFrames automatic low-memory rendering enabled rather than
forcing additional browser workers.
