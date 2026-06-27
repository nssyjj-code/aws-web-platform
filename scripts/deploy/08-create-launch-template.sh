#!/bin/bash

# scripts/deploy/08-create-launch-template.sh
# Creates an EC2 Launch Template for private application instances.

set -euo pipefail

export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"
USER_DATA_FILE="$ROOT_DIR/user-data/app-server.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Missing config file: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=../../config/environment.conf
# shellcheck disable=SC1091
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-web-platform}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"

VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"
APP_SG_NAME="${APP_SG_NAME:-$PROJECT_NAME-app-sg}"
LAUNCH_TEMPLATE_NAME="${LAUNCH_TEMPLATE_NAME:-$PROJECT_NAME-app-launch-template}"
EC2_INSTANCE_PROFILE_NAME="${EC2_INSTANCE_PROFILE_NAME:-$PROJECT_NAME-ec2-instance-profile}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

# shellcheck source=../lib/compute.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/compute.sh"

main() {
  validate_prerequisites

  if [[ ! -f "$USER_DATA_FILE" ]]; then
    log_error "User data file not found: $USER_DATA_FILE"
    exit 1
  fi

  log_info "Retrieving application security group..."

  local vpc_id
  local app_sg_id

  vpc_id="$(find_vpc_by_name "$VPC_NAME")"
  require_id "VPC" "$VPC_NAME" "$vpc_id"

  app_sg_id="$(find_security_group_by_name "$vpc_id" "$APP_SG_NAME")"
  require_id "Security Group" "$APP_SG_NAME" "$app_sg_id"

  log_success "Found application security group: $app_sg_id"

  log_info "Retrieving latest Amazon Linux 2023 AMI..."

  local ami_id
  ami_id="$(find_latest_amazon_linux_2023_ami)"

  require_id "AMI" "Amazon Linux 2023" "$ami_id"

  log_success "Using AMI: $ami_id"

  log_info "Ensuring launch template exists..."

  local launch_template_id
  launch_template_id="$(ensure_launch_template \
    "$LAUNCH_TEMPLATE_NAME" \
    "$ami_id" \
    "$INSTANCE_TYPE" \
    "$app_sg_id" \
    "$EC2_INSTANCE_PROFILE_NAME" \
    "$USER_DATA_FILE")"

  require_id "Launch Template" "$LAUNCH_TEMPLATE_NAME" "$launch_template_id"

  log_success "Launch template configured successfully: $launch_template_id"
}

main "$@"