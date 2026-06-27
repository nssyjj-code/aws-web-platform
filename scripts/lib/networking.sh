#!/bin/bash

# scripts/lib/networking.sh
# Shared VPC networking deployment helpers for the AWS Web Platform.

create_route_table() {
  local vpc_id="$1"
  local route_table_name="$2"
  local tier="$3"

  aws_cli ec2 create-route-table \
    --vpc-id "$vpc_id" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$route_table_name},{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=${ENVIRONMENT:-prod}},{Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}},{Key=Tier,Value=$tier}]" \
    --query "RouteTable.RouteTableId" \
    --output text
}

ensure_route_table() {
  local vpc_id="$1"
  local route_table_name="$2"
  local tier="$3"
  local route_table_id

  route_table_id="$(find_route_table_by_name "$vpc_id" "$route_table_name")"

  if ! exists "$route_table_id"; then
    log_info "Creating route table: $route_table_name"
    route_table_id="$(create_route_table "$vpc_id" "$route_table_name" "$tier")"
    log_success "Created route table $route_table_name: $route_table_id"
  else
    log_success "Route table already exists: $route_table_name ($route_table_id)"
  fi

  echo "$route_table_id"
}

allocate_eip() {
  local eip_name="$1"

  aws_cli ec2 allocate-address \
    --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$eip_name},{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=${ENVIRONMENT:-prod}},{Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}}]" \
    --query "AllocationId" \
    --output text
}

ensure_eip() {
  local eip_name="$1"
  local allocation_id

  allocation_id="$(find_eip_allocation_by_name "$eip_name")"

  if ! exists "$allocation_id"; then
    log_info "Allocating Elastic IP: $eip_name"
    allocation_id="$(allocate_eip "$eip_name")"
    log_success "Allocated Elastic IP $eip_name: $allocation_id"
  else
    log_success "Elastic IP already exists: $eip_name ($allocation_id)"
  fi

  echo "$allocation_id"
}

create_nat_gateway() {
  local nat_gateway_name="$1"
  local subnet_id="$2"
  local allocation_id="$3"

  aws_cli ec2 create-nat-gateway \
    --subnet-id "$subnet_id" \
    --allocation-id "$allocation_id" \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$nat_gateway_name},{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=${ENVIRONMENT:-prod}},{Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}}]" \
    --query "NatGateway.NatGatewayId" \
    --output text
}

ensure_nat_gateway() {
  local nat_gateway_name="$1"
  local subnet_id="$2"
  local allocation_id="$3"
  local nat_gateway_id

  nat_gateway_id="$(find_nat_gateway_by_name "$nat_gateway_name")"

  if ! exists "$nat_gateway_id"; then
    log_info "Creating NAT Gateway: $nat_gateway_name"
    nat_gateway_id="$(create_nat_gateway "$nat_gateway_name" "$subnet_id" "$allocation_id")"
    log_success "Created NAT Gateway $nat_gateway_name: $nat_gateway_id"
  else
    log_success "NAT Gateway already exists: $nat_gateway_name ($nat_gateway_id)"
  fi

  echo "$nat_gateway_id"
}

wait_for_nat_gateway() {
  local nat_gateway_id="$1"

  if ! exists "$nat_gateway_id"; then
    log_error "Cannot wait for NAT Gateway because ID is empty."
    exit 1
  fi

  log_info "Waiting for NAT Gateway to become available: $nat_gateway_id"

  aws_cli ec2 wait nat-gateway-available \
    --nat-gateway-ids "$nat_gateway_id"

  log_success "NAT Gateway is available: $nat_gateway_id"
}

ensure_route_to_nat_gateway() {
  local route_table_id="$1"
  local nat_gateway_id="$2"
  local existing_route

  existing_route="$(aws_cli ec2 describe-route-tables \
    --route-table-ids "$route_table_id" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId | [0]" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$existing_route" == "$nat_gateway_id" ]]; then
    log_success "Route already exists: 0.0.0.0/0 -> $nat_gateway_id"
  elif exists "$existing_route"; then
    log_error "Route table $route_table_id already has a different default NAT route: $existing_route"
    exit 1
  else
    log_info "Creating private route: 0.0.0.0/0 -> $nat_gateway_id"

    aws_cli ec2 create-route \
      --route-table-id "$route_table_id" \
      --destination-cidr-block "0.0.0.0/0" \
      --nat-gateway-id "$nat_gateway_id" >/dev/null

    log_success "Created private route: 0.0.0.0/0 -> $nat_gateway_id"
  fi
}