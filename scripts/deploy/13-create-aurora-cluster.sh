#!/bin/bash

# scripts/deploy/13-create-aurora-cluster.sh
# Creates a private Aurora MySQL cluster.

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

VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"
DB_SG_NAME="${DB_SG_NAME:-$PROJECT_NAME-db-sg}"
DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${PROJECT_NAME}-db-subnet-group}"
AURORA_CLUSTER_IDENTIFIER="${AURORA_CLUSTER_IDENTIFIER:-${PROJECT_NAME}-aurora-cluster}"

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
  validate_database_credentials

  log_info "Retrieving VPC ID..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"

  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "Found VPC: $vpc_id"

  log_info "Retrieving DB security group..."

  local db_sg_id
  db_sg_id="$(find_security_group_by_name "$vpc_id" "$DB_SG_NAME")"

  require_id "Security Group" "$DB_SG_NAME" "$db_sg_id"

  log_success "Found DB security group: $db_sg_id"

  log_info "Retrieving DB subnet group..."

  local db_subnet_group_result
  db_subnet_group_result="$(find_db_subnet_group_by_name "$DB_SUBNET_GROUP_NAME")"

  require_id "DB Subnet Group" "$DB_SUBNET_GROUP_NAME" "$db_subnet_group_result"

  log_success "Found DB subnet group: $db_subnet_group_result"

  log_info "Ensuring Aurora cluster exists..."

  local cluster_id
  cluster_id="$(ensure_aurora_cluster \
    "$AURORA_CLUSTER_IDENTIFIER" \
    "$DB_SUBNET_GROUP_NAME" \
    "$db_sg_id")"

  require_id "Aurora Cluster" "$AURORA_CLUSTER_IDENTIFIER" "$cluster_id"

  wait_for_aurora_cluster "$cluster_id"

  log_success "Aurora cluster configured successfully: $cluster_id"
}

main "$@"