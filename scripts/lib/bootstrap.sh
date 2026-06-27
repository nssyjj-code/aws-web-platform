#!/bin/bash

# scripts/lib/bootstrap.sh
# Shared bootstrap logic for AWS Web Platform automation scripts.

set -euo pipefail

export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"

readonly SCRIPT_DIR
readonly ROOT_DIR
readonly CONFIG_FILE

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Missing config file: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=../../config/environment.conf
# shellcheck disable=SC1091
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-web-platform}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
MANAGED_BY="${MANAGED_BY:-aws-cli}"

readonly AWS_REGION
readonly PROJECT_NAME
readonly ENVIRONMENT
readonly MANAGED_BY

# shellcheck source=./logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=./aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=./validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"