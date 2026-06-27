#!/bin/bash

# scripts/deploy/03-create-internet-gateway.sh
# Creates and attaches an Internet Gateway for the AWS Web Platform VPC.

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
IGW_NAME="${IGW_NAME:-$PROJECT_NAME-igw}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

create_igw() {
  aws_cli ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$IGW_NAME},{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=$ENVIRONMENT},{Key=ManagedBy,Value=$MANAGED_BY}]" \
    --query "InternetGateway.InternetGatewayId" \
    --output text
}

attach_igw() {
  local igw_id="$1"
  local vpc_id="$2"

  aws_cli ec2 attach-internet-gateway \
    --internet-gateway-id "$igw_id" \
    --vpc-id "$vpc_id" >/dev/null
}

verify_igw_attachment() {
  local igw_id="$1"

  aws_cli ec2 describe-internet-gateways \
    --internet-gateway-ids "$igw_id" \
    --query "InternetGateways[0].Attachments[0].VpcId" \
    --output text
}

main() {
  validate_prerequisites

  log_info "Retrieving VPC ID for $VPC_NAME..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"
  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "Found VPC: $vpc_id"

  log_info "Checking for existing Internet Gateway attached to $vpc_id..."

  local igw_id
  igw_id="$(find_igw_by_vpc_id "$vpc_id")"

  if ! exists "$igw_id"; then
    log_info "No Internet Gateway found. Creating one..."

    igw_id="$(create_igw)"

    log_success "Created Internet Gateway: $igw_id"

    log_info "Attaching Internet Gateway $igw_id to VPC $vpc_id..."

    attach_igw "$igw_id" "$vpc_id"

    log_success "Attached Internet Gateway $igw_id to VPC $vpc_id"
  else
    log_success "Internet Gateway already exists and is attached: $igw_id"
  fi

  log_info "Verifying Internet Gateway attachment..."

  local attached_vpc_id
  attached_vpc_id="$(verify_igw_attachment "$igw_id")"

  if [[ "$attached_vpc_id" != "$vpc_id" ]]; then
    log_error "Internet Gateway verification failed. Expected $vpc_id but found $attached_vpc_id."
    exit 1
  fi

  log_success "Internet Gateway is correctly attached to VPC $vpc_id."
}

main "$@"