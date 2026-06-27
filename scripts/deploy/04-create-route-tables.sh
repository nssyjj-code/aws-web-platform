#!/bin/bash

# scripts/deploy/04-create-route-tables.sh
# Creates and associates custom route tables for the AWS Web Platform VPC.

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
ENVIRONMENT="${ENVIRONMENT:-prod}"
PROJECT_NAME="${PROJECT_NAME:-aws-web-platform}"
MANAGED_BY="${MANAGED_BY:-aws-cli}"

VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"

PUBLIC_RT_NAME="${PUBLIC_RT_NAME:-$PROJECT_NAME-public-rt}"
PRIVATE_APP_RT_A_NAME="${PRIVATE_APP_RT_A_NAME:-$PROJECT_NAME-private-app-rt-a}"
PRIVATE_APP_RT_B_NAME="${PRIVATE_APP_RT_B_NAME:-$PROJECT_NAME-private-app-rt-b}"
PRIVATE_DB_RT_NAME="${PRIVATE_DB_RT_NAME:-$PROJECT_NAME-private-db-rt}"

PUBLIC_SUBNET_A_NAME="${PUBLIC_SUBNET_A_NAME:-$PROJECT_NAME-public-subnet-az1}"
PUBLIC_SUBNET_B_NAME="${PUBLIC_SUBNET_B_NAME:-$PROJECT_NAME-public-subnet-az2}"
PRIVATE_APP_SUBNET_A_NAME="${PRIVATE_APP_SUBNET_A_NAME:-$PROJECT_NAME-private-app-subnet-az1}"
PRIVATE_APP_SUBNET_B_NAME="${PRIVATE_APP_SUBNET_B_NAME:-$PROJECT_NAME-private-app-subnet-az2}"
PRIVATE_DB_SUBNET_A_NAME="${PRIVATE_DB_SUBNET_A_NAME:-$PROJECT_NAME-private-db-subnet-az1}"
PRIVATE_DB_SUBNET_B_NAME="${PRIVATE_DB_SUBNET_B_NAME:-$PROJECT_NAME-private-db-subnet-az2}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

# shellcheck source=../lib/networking.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/networking.sh"

create_public_route() {
  local route_table_id="$1"
  local igw_id="$2"
  local existing_gateway

  existing_gateway="$(aws_cli ec2 describe-route-tables \
    --route-table-ids "$route_table_id" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId | [0]" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$existing_gateway" == "$igw_id" ]]; then
    log_success "Public route already exists: 0.0.0.0/0 -> $igw_id"
    return 0
  fi

  if exists "$existing_gateway"; then
    log_error "Route table $route_table_id already has a different default route: $existing_gateway"
    exit 1
  fi

  log_info "Creating public internet route: 0.0.0.0/0 -> $igw_id"

  aws_cli ec2 create-route \
    --route-table-id "$route_table_id" \
    --destination-cidr-block "0.0.0.0/0" \
    --gateway-id "$igw_id" >/dev/null

  log_success "Created public route: 0.0.0.0/0 -> $igw_id"
}

associate_route_table() {
  local route_table_id="$1"
  local subnet_id="$2"
  local subnet_name="$3"
  local current_route_table_id
  local association_id

  current_route_table_id="$(aws_cli ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=$subnet_id" \
    --query "RouteTables[0].RouteTableId" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$current_route_table_id" == "$route_table_id" ]]; then
    log_success "$subnet_name is already associated with route table $route_table_id"
    return 0
  fi

  if exists "$current_route_table_id"; then
    log_warning "$subnet_name is associated with a different route table: $current_route_table_id"
    log_warning "Leaving existing association unchanged to avoid unexpected routing changes."
    return 0
  fi

  log_info "Associating $subnet_name with route table $route_table_id"

  association_id="$(aws_cli ec2 associate-route-table \
    --route-table-id "$route_table_id" \
    --subnet-id "$subnet_id" \
    --query "AssociationId" \
    --output text)"

  log_success "Associated $subnet_name with $route_table_id ($association_id)"
}

main() {
  validate_prerequisites

  log_info "Retrieving VPC ID..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"
  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "Found VPC: $vpc_id"

  log_info "Retrieving Internet Gateway ID..."

  local igw_id
  igw_id="$(find_igw_by_vpc_id "$vpc_id")"
  require_id "Internet Gateway attached to VPC" "$vpc_id" "$igw_id"

  log_success "Found Internet Gateway: $igw_id"

  local public_subnet_a_id
  local public_subnet_b_id
  local private_app_subnet_a_id
  local private_app_subnet_b_id
  local private_db_subnet_a_id
  local private_db_subnet_b_id

  public_subnet_a_id="$(find_subnet_by_name "$vpc_id" "$PUBLIC_SUBNET_A_NAME")"
  public_subnet_b_id="$(find_subnet_by_name "$vpc_id" "$PUBLIC_SUBNET_B_NAME")"
  private_app_subnet_a_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_APP_SUBNET_A_NAME")"
  private_app_subnet_b_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_APP_SUBNET_B_NAME")"
  private_db_subnet_a_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_DB_SUBNET_A_NAME")"
  private_db_subnet_b_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_DB_SUBNET_B_NAME")"

  require_id "Subnet" "$PUBLIC_SUBNET_A_NAME" "$public_subnet_a_id"
  require_id "Subnet" "$PUBLIC_SUBNET_B_NAME" "$public_subnet_b_id"
  require_id "Subnet" "$PRIVATE_APP_SUBNET_A_NAME" "$private_app_subnet_a_id"
  require_id "Subnet" "$PRIVATE_APP_SUBNET_B_NAME" "$private_app_subnet_b_id"
  require_id "Subnet" "$PRIVATE_DB_SUBNET_A_NAME" "$private_db_subnet_a_id"
  require_id "Subnet" "$PRIVATE_DB_SUBNET_B_NAME" "$private_db_subnet_b_id"

  local public_rt_id
  local private_app_rt_a_id
  local private_app_rt_b_id
  local private_db_rt_id

  public_rt_id="$(ensure_route_table "$vpc_id" "$PUBLIC_RT_NAME" "public")"
  private_app_rt_a_id="$(ensure_route_table "$vpc_id" "$PRIVATE_APP_RT_A_NAME" "private-app")"
  private_app_rt_b_id="$(ensure_route_table "$vpc_id" "$PRIVATE_APP_RT_B_NAME" "private-app")"
  private_db_rt_id="$(ensure_route_table "$vpc_id" "$PRIVATE_DB_RT_NAME" "private-db")"

  create_public_route "$public_rt_id" "$igw_id"

  associate_route_table "$public_rt_id" "$public_subnet_a_id" "$PUBLIC_SUBNET_A_NAME"
  associate_route_table "$public_rt_id" "$public_subnet_b_id" "$PUBLIC_SUBNET_B_NAME"

  associate_route_table "$private_app_rt_a_id" "$private_app_subnet_a_id" "$PRIVATE_APP_SUBNET_A_NAME"
  associate_route_table "$private_app_rt_b_id" "$private_app_subnet_b_id" "$PRIVATE_APP_SUBNET_B_NAME"

  associate_route_table "$private_db_rt_id" "$private_db_subnet_a_id" "$PRIVATE_DB_SUBNET_A_NAME"
  associate_route_table "$private_db_rt_id" "$private_db_subnet_b_id" "$PRIVATE_DB_SUBNET_B_NAME"

  log_success "Route tables created and associated successfully."
}

main "$@"