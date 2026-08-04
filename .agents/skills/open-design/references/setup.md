# Open Design Setup

Use `scripts/install-media-tools.sh` for the complete reproducible environment.
It installs the locked Open Design source checkout, verifies the pinned
HyperFrames CLI, disables HyperFrames telemetry, and provisions its browser.

## Prerequisites

- Git
- Node.js 24 and Corepack
- Bash
- `apt-get` plus root or `sudo` when FFmpeg is not already installed

## Install

In a Codespace, the default tool profile installs Open Design in under the
five-minute onboarding budget. Run the media installer once to opt into FFmpeg,
provision the HyperFrames browser, and disable its optional telemetry:

```bash
bash scripts/install-media-tools.sh
```

The Open Design lock pins `open-design-v0.17.0` at commit
`90a660add511da6408464a1bf3d4d5945ad06400`, Node `~24`, and pnpm `10.33.2`.
Its sparse checkout includes the daemon, Studio, packages and scripts, plus the
complete upstream design-system, design-template, functional-skill, and
prompt-template catalogs. Unrelated upstream applications, deployment assets,
fixtures, and repository development infrastructure remain excluded.

HyperFrames is independently pinned to `0.7.90`. Always use the repository
wrapper so Open Design cannot select a mutable renderer or install global skill
copies:

```bash
bash scripts/hyperframes.sh doctor
bash scripts/hyperframes.sh init videos/example --non-interactive --example=blank
bash scripts/hyperframes.sh lint videos/example
bash scripts/hyperframes.sh render videos/example --output videos/example/render.mp4
```

Do not run `hyperframes skills update`. The eight HyperFrames skill packages are
vendored at source commit `1e51eaec2cb6c058fbb5349c8c3dae9770d7f30c`
and validated through `skills-lock.json`.

## Open Design bootstrap only

Run the lower-level bootstrap when testing an isolated checkout or an MCP
client other than the committed project configuration:

```bash
bash .agents/skills/open-design/scripts/bootstrap.sh \
  --lock .agents/skills/open-design/open-design.lock \
  --install-dir /absolute/path/to/open-design \
  --mcp-client opencode
```

The supported interface is:

```text
.agents/skills/open-design/scripts/bootstrap.sh --lock PATH
  [--install-dir DIR] [--mcp-client NAME] [--apply-mcp]
```

The MCP operation is a dry-run unless `--apply-mcp` is passed. The project
already commits matching OpenCode and generic MCP definitions, so routine setup
does not need to mutate client configuration.

## Linux CLI name conflict

GNU coreutils installs `/usr/bin/od` for octal dumps. Run the project-local CLI
from the Open Design checkout:

```bash
node apps/daemon/bin/od.mjs --help
```

Restart OpenCode after installing or updating the skill or MCP configuration.

## Updates and cleanup

Update Open Design only by reviewing a release tag and commit together, then
changing the lock and rerunning the clean smoke test. Update HyperFrames only by
reviewing the npm integrity, matching source commit, wrapper pin, and all eight
skill packages in one change.

Remove the generated Open Design checkout with
`rm -rf ~/.local/share/open-design`. HyperFrames browser and package data use the
normal npm/Puppeteer user caches and are covered by the repository cache cleanup
workflow. Optional local transcription, speech, and music models are not
installed because they materially change disk and licensing requirements.

## Measured footprint

The issue #566 validation environment measured:

- Open Design checkout and dependencies: 1,641,192,538 bytes (about 1.53 GiB);
- HyperFrames cache after browser provisioning: 273,537,316 bytes (about 261 MiB);
- cold Open Design core installation: 222 seconds;
- repeat media installation with cached browser: 19 seconds.

The first media install additionally downloads the approximately 115 MB
headless browser and installs FFmpeg when absent. Network speed, package cache,
and available memory materially affect cold timing. The default Codespaces
profile excludes those renderer prerequisites so normal onboarding remains
under five minutes.
