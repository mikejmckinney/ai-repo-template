#!/usr/bin/env bash
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/regrade-stage.sh" 1c "$@"
