#!/bin/bash

# scripts/validation/validate-network.sh
# Validates VPC, subnet, route table, Internet Gateway, and NAT Gateway networking.

set -euo pipefail

export AWS_PAGER=""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../lib/bootstrap.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/bootstrap.sh"

# shellcheck source=../lib/networking.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/networking.sh"

VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"

validate_subnet() {
  local vpc_id="$1"
  local subnet_name="$2"

  local subnet_id
  subnet_id="$(find_subnet_by_name "$vpc_id" "$subnet_name")"

  require_id "Subnet" "$subnet_name" "$subnet_id"
  log_success "Subnet found: $subnet_name ($subnet_id)"
}

validate_route_table() {
  local vpc_id="$1"
  local route_table_name="$2"

  local route_table_id
  route_table_id="$(find_route_table_by_name "$vpc_id" "$route_table_name")"

  require_id "Route Table" "$route_table_name" "$route_table_id"
  log_success "Route table found: $route_table_name ($route_table_id)"
}

validate_public_route() {
  local route_table_id="$1"
  local igw_id="$2"

  local route_gateway
  route_gateway="$(aws_cli ec2 describe-route-tables \
    --route-table-ids "$route_table_id" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId | [0]" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$route_gateway" != "$igw_id" ]]; then
    log_error "Public route table does not route 0.0.0.0/0 to expected IGW."
    log_error "Expected: $igw_id"
    log_error "Found   : $route_gateway"
    exit 1
  fi

  log_success "Public default route validated: 0.0.0.0/0 -> $igw_id"
}

validate_private_nat_route() {
  local route_table_id="$1"
  local expected_nat_gateway_id="$2"

  local route_nat_gateway
  route_nat_gateway="$(aws_cli ec2 describe-route-tables \
    --route-table-ids "$route_table_id" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId | [0]" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$route_nat_gateway" != "$expected_nat_gateway_id" ]]; then
    log_error "Private app route table does not route 0.0.0.0/0 to expected NAT Gateway."
    log_error "Expected: $expected_nat_gateway_id"
    log_error "Found   : $route_nat_gateway"
    exit 1
  fi

  log_success "Private app default route validated: 0.0.0.0/0 -> $expected_nat_gateway_id"
}

validate_no_default_route() {
  local route_table_id="$1"
  local route_table_name="$2"

  local default_route
  default_route="$(aws_cli ec2 describe-route-tables \
    --route-table-ids "$route_table_id" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'] | length(@)" \
    --output text 2>/dev/null || echo "0")"

  if [[ "$default_route" != "0" ]]; then
    log_error "Database route table should not have a default internet route: $route_table_name"
    exit 1
  fi

  log_success "Database route table has no default internet route: $route_table_name"
}

validate_nat_gateway_available() {
  local nat_gateway_name="$1"

  local nat_gateway_id
  nat_gateway_id="$(find_nat_gateway_by_name "$nat_gateway_name")"

  require_id "NAT Gateway" "$nat_gateway_name" "$nat_gateway_id"

  local nat_state
  nat_state="$(aws_cli ec2 describe-nat-gateways \
    --nat-gateway-ids "$nat_gateway_id" \
    --query "NatGateways[0].State" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$nat_state" != "available" ]]; then
    log_error "NAT Gateway is not available: $nat_gateway_name ($nat_gateway_id), state=$nat_state"
    exit 1
  fi

  log_success "NAT Gateway available: $nat_gateway_name ($nat_gateway_id)"
}

main() {
  validate_prerequisites

  log_info "Validating network infrastructure..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"
  require_id "VPC" "$VPC_NAME" "$vpc_id"
  log_success "VPC found: $VPC_NAME ($vpc_id)"

  local igw_id
  igw_id="$(find_igw_by_vpc_id "$vpc_id")"
  require_id "Internet Gateway" "$VPC_NAME" "$igw_id"
  log_success "Internet Gateway attached: $igw_id"

  validate_subnet "$vpc_id" "$PUBLIC_SUBNET_A_NAME"
  validate_subnet "$vpc_id" "$PUBLIC_SUBNET_B_NAME"
  validate_subnet "$vpc_id" "$PRIVATE_APP_SUBNET_A_NAME"
  validate_subnet "$vpc_id" "$PRIVATE_APP_SUBNET_B_NAME"
  validate_subnet "$vpc_id" "$PRIVATE_DB_SUBNET_A_NAME"
  validate_subnet "$vpc_id" "$PRIVATE_DB_SUBNET_B_NAME"

  local public_rt_id
  local private_app_rt_a_id
  local private_app_rt_b_id
  local private_db_rt_id

  public_rt_id="$(find_route_table_by_name "$vpc_id" "$PUBLIC_RT_NAME")"
  private_app_rt_a_id="$(find_route_table_by_name "$vpc_id" "$PRIVATE_APP_RT_A_NAME")"
  private_app_rt_b_id="$(find_route_table_by_name "$vpc_id" "$PRIVATE_APP_RT_B_NAME")"
  private_db_rt_id="$(find_route_table_by_name "$vpc_id" "$PRIVATE_DB_RT_NAME")"

  require_id "Route Table" "$PUBLIC_RT_NAME" "$public_rt_id"
  require_id "Route Table" "$PRIVATE_APP_RT_A_NAME" "$private_app_rt_a_id"
  require_id "Route Table" "$PRIVATE_APP_RT_B_NAME" "$private_app_rt_b_id"
  require_id "Route Table" "$PRIVATE_DB_RT_NAME" "$private_db_rt_id"

  log_success "Route table found: $PUBLIC_RT_NAME ($public_rt_id)"
  log_success "Route table found: $PRIVATE_APP_RT_A_NAME ($private_app_rt_a_id)"
  log_success "Route table found: $PRIVATE_APP_RT_B_NAME ($private_app_rt_b_id)"
  log_success "Route table found: $PRIVATE_DB_RT_NAME ($private_db_rt_id)"

  validate_nat_gateway_available "$NAT_GW_A_NAME"
  validate_nat_gateway_available "$NAT_GW_B_NAME"

  local nat_gw_a_id
  local nat_gw_b_id

  nat_gw_a_id="$(find_nat_gateway_by_name "$NAT_GW_A_NAME")"
  nat_gw_b_id="$(find_nat_gateway_by_name "$NAT_GW_B_NAME")"

  validate_public_route "$public_rt_id" "$igw_id"
  validate_private_nat_route "$private_app_rt_a_id" "$nat_gw_a_id"
  validate_private_nat_route "$private_app_rt_b_id" "$nat_gw_b_id"
  validate_no_default_route "$private_db_rt_id" "$PRIVATE_DB_RT_NAME"

  log_success "Network validation completed successfully."
}

main "$@"