#!/usr/bin/env bash
# Pinned @cursor/sdk version for workflow npm installs.
# Bump only after sandbox/GHA verification — unpinned installs pulled 1.0.19
# (node:sqlite) and broke Agent.prompt on ephemeral runners (2026-06-16).
CURSOR_SDK_VERSION="${CURSOR_SDK_VERSION:-1.0.18}"
