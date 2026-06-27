#!/bin/bash

# scripts/deploy/11-create-auto-scaling-group.sh
# Creates an Auto Scaling Group for private application instances.

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
PRIVATE_APP_SUBNET_A_NAME="${PRIVATE_APP_SUBNET_A_NAME:-$PROJECT_NAME-private-app-subnet-az1}"
PRIVATE_APP_SUBNET_B_NAME="${PRIVATE_APP_SUBNET_B_NAME:-$PROJECT_NAME-private-app-subnet-az2}"
TARGET_GROUP_NAME="${TARGET_GROUP_NAME:-${PROJECT_NAME}-app-tg}"
LAUNCH_TEMPLATE_NAME="${LAUNCH_TEMPLATE_NAME:-$PROJECT_NAME-app-launch-template}"
ASG_NAME="${ASG_NAME:-${PROJECT_NAME}-app-asg}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

# shellcheck source=../lib/autoscaling.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/autoscaling.sh"

main() {
  validate_prerequisites

  log_info "Retrieving VPC ID..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"

  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "Found VPC: $vpc_id"

  log_info "Retrieving private application subnet IDs..."

  local private_app_subnet_a_id
  local private_app_subnet_b_id

  private_app_subnet_a_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_APP_SUBNET_A_NAME")"
  private_app_subnet_b_id="$(find_subnet_by_name "$vpc_id" "$PRIVATE_APP_SUBNET_B_NAME")"

  require_id "Private App Subnet" "$PRIVATE_APP_SUBNET_A_NAME" "$private_app_subnet_a_id"
  require_id "Private App Subnet" "$PRIVATE_APP_SUBNET_B_NAME" "$private_app_subnet_b_id"

  log_success "Found private app subnet AZ1: $private_app_subnet_a_id"
  log_success "Found private app subnet AZ2: $private_app_subnet_b_id"

  log_info "Retrieving target group..."

  local target_group_arn
  target_group_arn="$(find_target_group_by_name "$TARGET_GROUP_NAME")"

  require_id "Target Group" "$TARGET_GROUP_NAME" "$target_group_arn"

  log_success "Found target group: $target_group_arn"

  log_info "Retrieving launch template..."

  local launch_template_id
  launch_template_id="$(find_launch_template_by_name "$LAUNCH_TEMPLATE_NAME")"

  require_id "Launch Template" "$LAUNCH_TEMPLATE_NAME" "$launch_template_id"

  log_success "Found launch template: $launch_template_id"

  log_info "Ensuring Auto Scaling Group exists..."

  local asg_result
  asg_result="$(ensure_auto_scaling_group \
    "$ASG_NAME" \
    "$LAUNCH_TEMPLATE_NAME" \
    "$private_app_subnet_a_id" \
    "$private_app_subnet_b_id" \
    "$target_group_arn")"

  require_id "Auto Scaling Group" "$ASG_NAME" "$asg_result"

  log_success "Auto Scaling Group configured successfully: $ASG_NAME"
}

main "$@"