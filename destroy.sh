#!/bin/bash

# Root-level wrapper for AWS Web Platform environment destruction.
# Delegates execution to the main cleanup workflow.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESTROY_SCRIPT="$ROOT_DIR/scripts/cleanup/destroy-environment.sh"

if [[ ! -x "$DESTROY_SCRIPT" ]]; then
  echo "ERROR: Cleanup script is missing or not executable: $DESTROY_SCRIPT"
  exit 1
fi

exec "$DESTROY_SCRIPT" "$@"