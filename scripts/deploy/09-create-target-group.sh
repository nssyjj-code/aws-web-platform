#!/bin/bash

# scripts/deploy/09-create-target-group.sh
# Creates an Application Load Balancer target group for the AWS Web Platform.

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
TARGET_GROUP_NAME="${TARGET_GROUP_NAME:-${PROJECT_NAME}-app-tg}"
TARGET_GROUP_HEALTH_CHECK_PATH="${TARGET_GROUP_HEALTH_CHECK_PATH:-/health.html}"

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

  log_info "Ensuring target group exists..."

  local target_group_arn
  target_group_arn="$(ensure_target_group \
    "$TARGET_GROUP_NAME" \
    "$vpc_id" \
    "HTTP" \
    80 \
    "$TARGET_GROUP_HEALTH_CHECK_PATH")"

  require_id "Target Group" "$TARGET_GROUP_NAME" "$target_group_arn"

  log_success "Target group configured successfully: $target_group_arn"
}

main "$@"