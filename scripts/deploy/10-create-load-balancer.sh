#!/bin/bash

# scripts/deploy/10-create-load-balancer.sh
# Creates an internet-facing Application Load Balancer and HTTP listener.

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
PUBLIC_SUBNET_A_NAME="${PUBLIC_SUBNET_A_NAME:-$PROJECT_NAME-public-subnet-az1}"
PUBLIC_SUBNET_B_NAME="${PUBLIC_SUBNET_B_NAME:-$PROJECT_NAME-public-subnet-az2}"
ALB_SG_NAME="${ALB_SG_NAME:-$PROJECT_NAME-alb-sg}"
TARGET_GROUP_NAME="${TARGET_GROUP_NAME:-${PROJECT_NAME}-app-tg}"
ALB_NAME="${ALB_NAME:-${PROJECT_NAME}-alb}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

# shellcheck source=../lib/load-balancing.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/load-balancing.sh"

main() {
  validate_prerequisites

  log_info "Retrieving VPC ID..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"

  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "Found VPC: $vpc_id"

  log_info "Retrieving public subnet IDs..."

  local public_subnet_a_id
  local public_subnet_b_id

  public_subnet_a_id="$(find_subnet_by_name "$vpc_id" "$PUBLIC_SUBNET_A_NAME")"
  public_subnet_b_id="$(find_subnet_by_name "$vpc_id" "$PUBLIC_SUBNET_B_NAME")"

  require_id "Public Subnet" "$PUBLIC_SUBNET_A_NAME" "$public_subnet_a_id"
  require_id "Public Subnet" "$PUBLIC_SUBNET_B_NAME" "$public_subnet_b_id"

  log_success "Found public subnet AZ1: $public_subnet_a_id"
  log_success "Found public subnet AZ2: $public_subnet_b_id"

  log_info "Retrieving ALB security group..."

  local alb_sg_id
  alb_sg_id="$(find_security_group_by_name "$vpc_id" "$ALB_SG_NAME")"

  require_id "Security Group" "$ALB_SG_NAME" "$alb_sg_id"

  log_success "Found ALB security group: $alb_sg_id"

  log_info "Retrieving target group..."

  local target_group_arn
  target_group_arn="$(find_target_group_by_name "$TARGET_GROUP_NAME")"

  require_id "Target Group" "$TARGET_GROUP_NAME" "$target_group_arn"

  log_success "Found target group: $target_group_arn"

  log_info "Ensuring Application Load Balancer exists..."

  local alb_arn
  alb_arn="$(ensure_load_balancer \
    "$ALB_NAME" \
    "$public_subnet_a_id" \
    "$public_subnet_b_id" \
    "$alb_sg_id")"

  require_id "Application Load Balancer" "$ALB_NAME" "$alb_arn"

  log_success "Application Load Balancer ready: $alb_arn"

  log_info "Ensuring HTTP listener exists..."

  local listener_arn
  listener_arn="$(ensure_http_listener "$alb_arn" "$target_group_arn")"

  require_id "HTTP Listener" "$ALB_NAME" "$listener_arn"

  log_success "HTTP listener ready: $listener_arn"

  local alb_dns

  alb_dns="$(aws_cli elbv2 describe-load-balancers \
    --load-balancer-arns "$alb_arn" \
    --query "LoadBalancers[0].DNSName" \
    --output text)"

  log_success "Application Load Balancer configured successfully."
  log_info "ALB DNS Name: http://$alb_dns"
}

main "$@"