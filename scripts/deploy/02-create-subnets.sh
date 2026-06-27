#!/bin/bash

# scripts/deploy/02-create-subnets.sh
# Creates public, private application, and private database subnets for the AWS Web Platform.

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

AZ1="${AZ1:-us-east-1a}"
AZ2="${AZ2:-us-east-1b}"

VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"

PUBLIC_SUBNET_A_NAME="${PUBLIC_SUBNET_A_NAME:-$PROJECT_NAME-public-subnet-az1}"
PUBLIC_SUBNET_B_NAME="${PUBLIC_SUBNET_B_NAME:-$PROJECT_NAME-public-subnet-az2}"

PRIVATE_APP_SUBNET_A_NAME="${PRIVATE_APP_SUBNET_A_NAME:-$PROJECT_NAME-private-app-subnet-az1}"
PRIVATE_APP_SUBNET_B_NAME="${PRIVATE_APP_SUBNET_B_NAME:-$PROJECT_NAME-private-app-subnet-az2}"

PRIVATE_DB_SUBNET_A_NAME="${PRIVATE_DB_SUBNET_A_NAME:-$PROJECT_NAME-private-db-subnet-az1}"
PRIVATE_DB_SUBNET_B_NAME="${PRIVATE_DB_SUBNET_B_NAME:-$PROJECT_NAME-private-db-subnet-az2}"

PUBLIC_SUBNET_A_CIDR="${PUBLIC_SUBNET_A_CIDR:-10.0.1.0/24}"
PUBLIC_SUBNET_B_CIDR="${PUBLIC_SUBNET_B_CIDR:-10.0.2.0/24}"

PRIVATE_APP_SUBNET_A_CIDR="${PRIVATE_APP_SUBNET_A_CIDR:-10.0.11.0/24}"
PRIVATE_APP_SUBNET_B_CIDR="${PRIVATE_APP_SUBNET_B_CIDR:-10.0.12.0/24}"

PRIVATE_DB_SUBNET_A_CIDR="${PRIVATE_DB_SUBNET_A_CIDR:-10.0.21.0/24}"
PRIVATE_DB_SUBNET_B_CIDR="${PRIVATE_DB_SUBNET_B_CIDR:-10.0.22.0/24}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

validate_prerequisites

log_info "Retrieving VPC ID for $VPC_NAME..."

VPC_ID="$(find_vpc_by_name "$VPC_NAME")"
require_id "VPC" "$VPC_NAME" "$VPC_ID"

log_success "Found VPC: $VPC_ID"

create_subnet() {
  local subnet_name="$1"
  local cidr_block="$2"
  local availability_zone="$3"
  local tier="$4"
  local map_public_ip="$5"
  local existing_subnet_id
  local subnet_id

  log_info "Checking subnet: $subnet_name"

  existing_subnet_id="$(aws_cli ec2 describe-subnets \
    --filters \
      "Name=vpc-id,Values=$VPC_ID" \
      "Name=tag:Name,Values=$subnet_name" \
      "Name=cidr-block,Values=$cidr_block" \
    --query "Subnets[0].SubnetId" \
    --output text 2>/dev/null || echo "None")"

  if exists "$existing_subnet_id"; then
    subnet_id="$existing_subnet_id"
    log_success "Subnet already exists: $subnet_name ($subnet_id)"
  else
    log_info "Creating subnet: $subnet_name"

    subnet_id="$(aws_cli ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$cidr_block" \
      --availability-zone "$availability_zone" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$subnet_name},{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=$ENVIRONMENT},{Key=ManagedBy,Value=$MANAGED_BY},{Key=Tier,Value=$tier}]" \
      --query "Subnet.SubnetId" \
      --output text)"

    log_success "Created subnet: $subnet_name ($subnet_id)"
  fi

  log_info "Waiting for subnet to become available: $subnet_name"

  aws_cli ec2 wait subnet-available \
    --subnet-ids "$subnet_id"

  if [[ "$map_public_ip" == "true" ]]; then
    log_info "Enabling auto-assign public IPv4 for $subnet_name"

    aws_cli ec2 modify-subnet-attribute \
      --subnet-id "$subnet_id" \
      --map-public-ip-on-launch

    log_success "Auto-assign public IPv4 enabled for $subnet_name"
  else
    log_info "Ensuring auto-assign public IPv4 is disabled for $subnet_name"

    aws_cli ec2 modify-subnet-attribute \
      --subnet-id "$subnet_id" \
      --no-map-public-ip-on-launch

    log_success "Auto-assign public IPv4 disabled for $subnet_name"
  fi
}

create_subnet "$PUBLIC_SUBNET_A_NAME" "$PUBLIC_SUBNET_A_CIDR" "$AZ1" "public" "true"
create_subnet "$PUBLIC_SUBNET_B_NAME" "$PUBLIC_SUBNET_B_CIDR" "$AZ2" "public" "true"

create_subnet "$PRIVATE_APP_SUBNET_A_NAME" "$PRIVATE_APP_SUBNET_A_CIDR" "$AZ1" "private-app" "false"
create_subnet "$PRIVATE_APP_SUBNET_B_NAME" "$PRIVATE_APP_SUBNET_B_CIDR" "$AZ2" "private-app" "false"

create_subnet "$PRIVATE_DB_SUBNET_A_NAME" "$PRIVATE_DB_SUBNET_A_CIDR" "$AZ1" "private-db" "false"
create_subnet "$PRIVATE_DB_SUBNET_B_NAME" "$PRIVATE_DB_SUBNET_B_CIDR" "$AZ2" "private-db" "false"

log_success "Subnet setup complete."