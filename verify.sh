#!/bin/bash

# Root-level wrapper for AWS Web Platform environment validation.
# Delegates execution to the main verification workflow.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$ROOT_DIR/scripts/validation/verify-environment.sh"

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "ERROR: Verification script is missing or not executable: $VERIFY_SCRIPT"
  exit 1
fi

exec "$VERIFY_SCRIPT" "$@"