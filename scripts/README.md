# Scripts Directory

> **Purpose**: Automation scripts for common development tasks. "If it happens twice, automate it."

## Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `verify-env.sh` | Check environment setup | `./scripts/verify-env.sh` |
| `setup.sh` | One-command project setup | `./scripts/setup.sh` |
| `format.sh` | Check or apply deterministic shell/Markdown formatting | `./scripts/format.sh --check <files...>` |
| `install-codespace-tools.sh` | Install or verify pinned Codespaces tool profiles | `./scripts/install-codespace-tools.sh --profile default` |
| `browser-mcp.sh` | Launch pinned browser MCP packages with pinned Chrome for Testing | Called by generated MCP configuration |
| `elevenlabs-mcp.sh` | Launch pinned ElevenLabs MCP with repository-local ignored audio output | Called by generated MCP configuration |
| `mureka-mcp.sh` | Launch pinned Mureka MCP with generation timeout defaults | Called by generated MCP configuration |
| `suno-mcp.sh` | Launch pinned third-party Ace Data Cloud Suno MCP | Called by generated MCP configuration |
| `check-markdown-links.py` | Validate repository-local Markdown targets | `python3 scripts/check-markdown-links.py <files...>` |
| `cleanup-codespace-caches.sh` | Report or clean reproducible Codespaces caches | `./scripts/cleanup-codespace-caches.sh [--apply]` |
| `sync-opencode-oauth-secret.sh` | Preview or sync access-only OpenCode OAuth to Actions | `./scripts/sync-opencode-oauth-secret.sh [--apply]` |
| `create-derived-repo.sh` | Preview or create a derived repo and sync allowlisted credentials | `./scripts/create-derived-repo.sh --repo OWNER/PROJECT [--apply]` |
| `diagnose-opencode-session.sh` | Record OpenCode process exit and signal evidence | `./scripts/diagnose-opencode-session.sh` |

## Usage Guidelines

### For Agents

Before marking a task complete, run verification:
```bash
./scripts/verify-env.sh
```

### For Developers

One-command setup for new clones:
```bash
./scripts/setup.sh
```

Codespaces tool bootstrap installs core plus agent tools by default. It can be
checked without mutation:

```bash
./scripts/install-codespace-tools.sh --profile default --verify-only
```

Use `--profile core` for only the quality/runtime prerequisites. The explicit
agent profile preserves the same core-plus-agent union as the default:

```bash
./scripts/install-codespace-tools.sh --profile agents
```

Preview package and build caches when a Codespace approaches its storage limit:

```bash
./scripts/cleanup-codespace-caches.sh
```

The preview does not modify files. Use `--apply` to clean npm content and npx,
Bun, uv, pip, and Go caches. Cleanup skips uv while a uv process is active and
never removes agent databases, history, credentials, installed tools, or editor
extensions. The next package or tool invocation may require network access and
take longer while its cache is rebuilt.

Preview the expiration of the local OpenCode OpenAI OAuth credential:

```bash
./scripts/sync-opencode-oauth-secret.sh
```

Pass `--apply` to update `OPENCODE_OPENAI_AUTH` in the current repository. The
uploaded JSON contains the current access token, expiration, and account ID, but
replaces the real refresh token with `ci-refresh-disabled`. Output includes only
repository and expiration metadata. Expired access is rejected before upload.
In Codespaces, `codespace-post-start.sh` attempts this update automatically after
PAT setup and treats failure as non-fatal; stale credentials automatically omit
Sol in Actions.

## Creating New Scripts

1. Create the script in this directory
2. Add a shebang: `#!/bin/bash`
3. Make it executable: `chmod +x scripts/your-script.sh`
4. Add error handling: `set -e` (exit on error)
5. Document it in this README
6. Add to `test.sh` verification if critical

## Script Template

```bash
#!/bin/bash
# Description: What this script does
# Usage: ./scripts/script-name.sh [args]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# Your script logic here

log_info "Done!"
```

## Best Practices

1. **Idempotent**: Scripts should be safe to run multiple times
2. **Verbose**: Output what's happening for debugging
3. **Fail Fast**: Use `set -e` to stop on first error
4. **Check Dependencies**: Verify required tools exist before running
5. **Document**: Add usage comments at the top of each script
