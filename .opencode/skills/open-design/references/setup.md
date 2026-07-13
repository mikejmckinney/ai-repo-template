# Open Design Setup

Use the skill bootstrap script for a reproducible source install. It consumes
the repository, ref, commit, and install directory from a project lock file.
Consult the same lock for the project's verified Node and package-manager
versions before running it.

## Prerequisites

- Git
- Node.js and Corepack versions compatible with the selected lock file
- Bash
- `ffmpeg` only for workflows that render or optimize video

## Bootstrap

From a repository that contains the skill and an Open Design lock file:

```bash
bash .opencode/skills/open-design/scripts/bootstrap.sh \
  --lock path/to/open-design.lock \
  --mcp-client opencode
```

The default MCP operation is a dry-run: review the generated configuration
without writing it. Apply the configuration only after reviewing it:

```bash
bash .opencode/skills/open-design/scripts/bootstrap.sh \
  --lock path/to/open-design.lock \
  --mcp-client opencode \
  --apply-mcp
```

Override the lock's installation directory when isolation or debugging
requires a separate clone:

```bash
bash .opencode/skills/open-design/scripts/bootstrap.sh \
  --lock path/to/open-design.lock \
  --install-dir /absolute/path/to/open-design \
  --mcp-client opencode
```

The supported interface is:

```text
.opencode/skills/open-design/scripts/bootstrap.sh --lock PATH
  [--install-dir DIR] [--mcp-client NAME] [--apply-mcp]
```

## Linux CLI name conflict

GNU coreutils installs `/usr/bin/od` for octal dumps. Do not assume a bare
`od` command invokes Open Design. Run the project-local CLI from the Open
Design checkout:

```bash
pnpm exec od --help
```

## Reuse the skill globally

To make the skill available outside one repository, copy the complete skill
directory, including `scripts/` and `references/`, into OpenCode's global
skill directory:

```bash
mkdir -p ~/.config/opencode/skills/open-design
cp -R .opencode/skills/open-design/. \
  ~/.config/opencode/skills/open-design/
```

Run the global bootstrap script with the lock file for the project being
configured:

```bash
bash ~/.config/opencode/skills/open-design/scripts/bootstrap.sh \
  --lock /absolute/path/to/open-design.lock \
  --mcp-client opencode
```

Restart OpenCode after installing or updating the skill, and after applying
MCP configuration. OpenCode loads skill and MCP configuration at startup.
