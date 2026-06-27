#!/bin/bash

# scripts/deploy/01-create-vpc.sh
# Creates the base VPC for the AWS Web Platform.

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
VPC_CIDR="${VPC_CIDR:-10.0.0.0/16}"
VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"
MANAGED_BY="${MANAGED_BY:-aws-cli}"

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

log_info "Checking for existing VPC: $VPC_NAME"

EXISTING_VPC_ID="$(aws_cli ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" "Name=cidr-block,Values=$VPC_CIDR" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null || echo "None")"

if exists "$EXISTING_VPC_ID"; then
  log_success "VPC already exists: $VPC_NAME ($EXISTING_VPC_ID)"
  exit 0
fi

log_info "Creating VPC: $VPC_NAME"

VPC_ID="$(aws_cli ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME},{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=$ENVIRONMENT},{Key=ManagedBy,Value=$MANAGED_BY}]" \
  --query "Vpc.VpcId" \
  --output text)"

log_success "Created VPC: $VPC_ID"

log_info "Configuring VPC DNS settings..."

aws_cli ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support '{"Value":true}'

aws_cli ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames '{"Value":true}'

log_info "Waiting for VPC to become available..."

aws_cli ec2 wait vpc-available \
  --vpc-ids "$VPC_ID"

log_success "VPC setup complete: $VPC_NAME ($VPC_ID)"