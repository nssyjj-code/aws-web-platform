#!/bin/bash

# scripts/deploy/07-create-ec2-iam-role.sh
# Creates the EC2 IAM role and instance profile used by application instances.

set -euo pipefail

export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"
TRUST_POLICY_PATH="$ROOT_DIR/policies/ec2-trust-policy.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Missing config file: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=../../config/environment.conf
# shellcheck disable=SC1091
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-web-platform}"
EC2_ROLE_NAME="${EC2_ROLE_NAME:-$PROJECT_NAME-ec2-role}"
EC2_INSTANCE_PROFILE_NAME="${EC2_INSTANCE_PROFILE_NAME:-$PROJECT_NAME-ec2-instance-profile}"
SSM_MANAGED_POLICY_ARN="${SSM_MANAGED_POLICY_ARN:-arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

# shellcheck source=../lib/iam.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/iam.sh"

main() {
  validate_prerequisites

  if [[ ! -f "$TRUST_POLICY_PATH" ]]; then
    log_error "Trust policy file not found: $TRUST_POLICY_PATH"
    exit 1
  fi

  log_info "Ensuring EC2 IAM role exists..."

  local role_name
  role_name="$(ensure_ec2_role "$EC2_ROLE_NAME" "$TRUST_POLICY_PATH")"

  require_id "IAM Role" "$EC2_ROLE_NAME" "$role_name"

  log_success "IAM role ready: $role_name"

  log_info "Ensuring SSM managed policy is attached..."

  ensure_role_policy_attachment "$EC2_ROLE_NAME" "$SSM_MANAGED_POLICY_ARN"

  log_success "SSM managed policy attached or already present."

  log_info "Ensuring EC2 instance profile exists..."

  local instance_profile_name
  instance_profile_name="$(ensure_instance_profile "$EC2_INSTANCE_PROFILE_NAME")"

  require_id "Instance Profile" "$EC2_INSTANCE_PROFILE_NAME" "$instance_profile_name"

  log_success "Instance profile ready: $instance_profile_name"

  log_info "Ensuring role is added to instance profile..."

  ensure_role_in_instance_profile "$EC2_INSTANCE_PROFILE_NAME" "$EC2_ROLE_NAME"

  log_success "EC2 IAM role and instance profile configured successfully."
}

main "$@"