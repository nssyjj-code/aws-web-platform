#!/bin/bash

# scripts/deploy/14-create-aurora-instance.sh
# Creates the Aurora writer instance for the private Aurora MySQL cluster.

set -euo pipefail

export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Missing config file: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=../../config/environment.conf
# shellcheck disable=SC1091
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-web-platform}"

AURORA_CLUSTER_IDENTIFIER="${AURORA_CLUSTER_IDENTIFIER:-${PROJECT_NAME}-aurora-cluster}"
AURORA_WRITER_INSTANCE_IDENTIFIER="${AURORA_WRITER_INSTANCE_IDENTIFIER:-${PROJECT_NAME}-aurora-writer-1}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

# shellcheck source=../lib/database.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/database.sh"

main() {
  validate_prerequisites

  log_info "Retrieving Aurora cluster..."

  local cluster_id
  cluster_id="$(find_db_cluster_by_identifier "$AURORA_CLUSTER_IDENTIFIER")"

  require_id "Aurora Cluster" "$AURORA_CLUSTER_IDENTIFIER" "$cluster_id"

  log_success "Found Aurora cluster: $cluster_id"

  log_info "Ensuring Aurora writer instance exists..."

  local instance_id
  instance_id="$(ensure_aurora_instance "$AURORA_WRITER_INSTANCE_IDENTIFIER" "$cluster_id")"

  require_id "Aurora Instance" "$AURORA_WRITER_INSTANCE_IDENTIFIER" "$instance_id"

  wait_for_aurora_instance "$instance_id"

  log_success "Aurora writer instance configured successfully: $instance_id"
}

main "$@"