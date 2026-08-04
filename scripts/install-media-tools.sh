#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

bash scripts/install-codespace-tools.sh --profile core
bash scripts/install-codespace-tools.sh --profile media

bash scripts/hyperframes.sh --version
bash scripts/hyperframes.sh telemetry disable
bash scripts/hyperframes.sh browser ensure

printf '\nMedia tooling installation complete. Restart the agent client to reload MCP and skills.\n'
