#!/bin/bash

# scripts/deploy/12-create-rds-subnet-group.sh
# Creates an RDS subnet group using private database subnets.

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
PRIVATE_DB_SUBNET_A_NAME="${PRIVATE_DB_SUBNET_A_NAME:-$PROJECT_NAME-private-db-subnet-az1}"
PRIVATE_DB_SUBNET_B_NAME="${PRIVATE_DB_SUBNET_B_NAME:-$PROJECT_NAME-private-db-subnet-az2}"
DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${PROJECT_NAME}-db-subnet-group}"

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

  log_info "Retrieving VPC ID..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"

  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "Found VPC: $vpc_id"

  log_info "Retrieving private database subnet IDs..."

  local private_db_subnet_a_id
  local private_db_subnet_b_id

  private_db_subnet_a_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_DB_SUBNET_A_NAME")"
  private_db_subnet_b_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_DB_SUBNET_B_NAME")"

  require_id "Private DB Subnet" "$PRIVATE_DB_SUBNET_A_NAME" "$private_db_subnet_a_id"
  require_id "Private DB Subnet" "$PRIVATE_DB_SUBNET_B_NAME" "$private_db_subnet_b_id"

  log_success "Found private DB subnet AZ1: $private_db_subnet_a_id"
  log_success "Found private DB subnet AZ2: $private_db_subnet_b_id"

  log_info "Ensuring DB subnet group exists..."

  local db_subnet_group_result
  db_subnet_group_result="$(ensure_db_subnet_group \
    "$DB_SUBNET_GROUP_NAME" \
    "$private_db_subnet_a_id" \
    "$private_db_subnet_b_id")"

  require_id "DB Subnet Group" "$DB_SUBNET_GROUP_NAME" "$db_subnet_group_result"

  log_success "DB subnet group configured successfully: $db_subnet_group_result"
}

main "$@"