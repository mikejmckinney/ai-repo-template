#!/usr/bin/env bash
# Print ISO week id (YYYY-Www) for RUN_DATE or UTC today.
set -euo pipefail

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
date -u -d "${RUN_DATE}" +%G-W%V
