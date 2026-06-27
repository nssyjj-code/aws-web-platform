#!/bin/bash

# Root-level wrapper for full AWS Web Platform deployment.
# Delegates execution to the main deployment workflow.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$ROOT_DIR/scripts/deploy/deploy.sh"

if [[ ! -x "$DEPLOY_SCRIPT" ]]; then
  echo "ERROR: Deployment script is missing or not executable: $DEPLOY_SCRIPT"
  exit 1
fi

exec "$DEPLOY_SCRIPT" "$@"