#!/bin/bash

# scripts/validation/validate-security.sh
# Validates security groups, public exposure, IAM instance profile, and private tier isolation.

set -euo pipefail

export AWS_PAGER=""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../lib/bootstrap.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/bootstrap.sh"

VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"

security_group_exists() {
  local vpc_id="$1"
  local security_group_name="$2"

  find_security_group_by_name "$vpc_id" "$security_group_name"
}

validate_sg_exists() {
  local vpc_id="$1"
  local security_group_name="$2"

  local security_group_id
  security_group_id="$(security_group_exists "$vpc_id" "$security_group_name")"

  require_id "Security Group" "$security_group_name" "$security_group_id"
  log_success "Security group found: $security_group_name ($security_group_id)"

  echo "$security_group_id"
}

validate_ingress_cidr_rule() {
  local security_group_id="$1"
  local protocol="$2"
  local from_port="$3"
  local to_port="$4"
  local cidr="$5"
  local description="$6"

  local result
  result="$(aws_cli ec2 describe-security-groups \
    --group-ids "$security_group_id" \
    --query "SecurityGroups[0].IpPermissions[?IpProtocol=='$protocol' && FromPort==\`$from_port\` && ToPort==\`$to_port\` && contains(IpRanges[].CidrIp, '$cidr')]" \
    --output text 2>/dev/null || true)"

  if [[ -z "$result" ]]; then
    log_error "Missing ingress rule: $description"
    log_error "Expected: $protocol $from_port-$to_port from $cidr on $security_group_id"
    exit 1
  fi

  log_success "Validated ingress rule: $description"
}

validate_ingress_sg_rule() {
  local security_group_id="$1"
  local protocol="$2"
  local from_port="$3"
  local to_port="$4"
  local source_sg_id="$5"
  local description="$6"

  local result
  result="$(aws_cli ec2 describe-security-groups \
    --group-ids "$security_group_id" \
    --query "SecurityGroups[0].IpPermissions[?IpProtocol=='$protocol' && FromPort==\`$from_port\` && ToPort==\`$to_port\` && contains(UserIdGroupPairs[].GroupId, '$source_sg_id')]" \
    --output text 2>/dev/null || true)"

  if [[ -z "$result" ]]; then
    log_error "Missing security-group ingress rule: $description"
    log_error "Expected: $protocol $from_port-$to_port from $source_sg_id on $security_group_id"
    exit 1
  fi

  log_success "Validated security-group ingress rule: $description"
}

validate_no_public_ssh() {
  local security_group_id="$1"
  local security_group_name="$2"

  local result
  result="$(aws_cli ec2 describe-security-groups \
    --group-ids "$security_group_id" \
    --query "SecurityGroups[0].IpPermissions[?IpProtocol=='tcp' && FromPort==\`22\` && ToPort==\`22\` && contains(IpRanges[].CidrIp, '0.0.0.0/0')]" \
    --output text 2>/dev/null || true)"

  if [[ -n "$result" ]]; then
    log_error "Public SSH exposure detected on security group: $security_group_name"
    exit 1
  fi

  log_success "No public SSH exposure detected: $security_group_name"
}

validate_no_public_database_access() {
  local security_group_id="$1"
  local security_group_name="$2"

  local result
  result="$(aws_cli ec2 describe-security-groups \
    --group-ids "$security_group_id" \
    --query "SecurityGroups[0].IpPermissions[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && contains(IpRanges[].CidrIp, '0.0.0.0/0')]" \
    --output text 2>/dev/null || true)"

  if [[ -n "$result" ]]; then
    log_error "Public database exposure detected on security group: $security_group_name"
    exit 1
  fi

  log_success "No public database exposure detected: $security_group_name"
}

validate_instances_private() {
  local vpc_id="$1"

  local public_instance_count
  public_instance_count="$(aws_cli ec2 describe-instances \
    --filters \
      "Name=vpc-id,Values=$vpc_id" \
      "Name=tag:Project,Values=$PROJECT_NAME" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[?PublicIpAddress!=null].InstanceId | length(@)" \
    --output text 2>/dev/null || echo "0")"

  if [[ "$public_instance_count" != "0" ]]; then
    log_error "Application instances with public IPs detected: $public_instance_count"
    exit 1
  fi

  log_success "Application instances do not have public IP addresses."
}

validate_aurora_private() {
  local instance_identifier="$1"

  local publicly_accessible
  publicly_accessible="$(aws_cli rds describe-db-instances \
    --db-instance-identifier "$instance_identifier" \
    --query "DBInstances[0].PubliclyAccessible" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$publicly_accessible" != "False" ]]; then
    log_error "Aurora instance is publicly accessible or could not be validated: $instance_identifier"
    log_error "PubliclyAccessible value: $publicly_accessible"
    exit 1
  fi

  log_success "Aurora instance is private: $instance_identifier"
}

validate_instance_profile_exists() {
  local instance_profile_name="$1"

  local profile
  profile="$(aws iam get-instance-profile \
    --instance-profile-name "$instance_profile_name" \
    --query "InstanceProfile.InstanceProfileName" \
    --output text 2>/dev/null || echo "None")"

  require_id "Instance Profile" "$instance_profile_name" "$profile"

  log_success "IAM instance profile exists: $profile"
}

validate_role_attached_to_instance_profile() {
  local instance_profile_name="$1"
  local role_name="$2"

  local attached_role
  attached_role="$(aws iam get-instance-profile \
    --instance-profile-name "$instance_profile_name" \
    --query "InstanceProfile.Roles[?RoleName=='$role_name'].RoleName | [0]" \
    --output text 2>/dev/null || echo "None")"

  if [[ "$attached_role" != "$role_name" ]]; then
    log_error "IAM role is not attached to instance profile."
    log_error "Role: $role_name"
    log_error "Instance profile: $instance_profile_name"
    exit 1
  fi

  log_success "IAM role attached to instance profile: $role_name"
}

main() {
  validate_prerequisites

  log_info "Validating security architecture..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"
  require_id "VPC" "$VPC_NAME" "$vpc_id"

  local alb_sg_id
  local app_sg_id
  local db_sg_id

  alb_sg_id="$(validate_sg_exists "$vpc_id" "$ALB_SG_NAME")"
  app_sg_id="$(validate_sg_exists "$vpc_id" "$APP_SG_NAME")"
  db_sg_id="$(validate_sg_exists "$vpc_id" "$DB_SG_NAME")"

  validate_ingress_cidr_rule "$alb_sg_id" "tcp" 80 80 "0.0.0.0/0" "ALB allows HTTP from internet"

  if [[ "${ENABLE_HTTPS:-false}" == "true" ]]; then
    validate_ingress_cidr_rule "$alb_sg_id" "tcp" 443 443 "0.0.0.0/0" "ALB allows HTTPS from internet"
  else
    log_info "HTTPS validation skipped because ENABLE_HTTPS=false."
  fi

  validate_ingress_sg_rule "$app_sg_id" "tcp" 80 80 "$alb_sg_id" "Application tier allows HTTP from ALB only"
  validate_ingress_sg_rule "$db_sg_id" "tcp" 3306 3306 "$app_sg_id" "Database tier allows MySQL from app tier only"

  validate_no_public_ssh "$alb_sg_id" "$ALB_SG_NAME"
  validate_no_public_ssh "$app_sg_id" "$APP_SG_NAME"
  validate_no_public_ssh "$db_sg_id" "$DB_SG_NAME"

  validate_no_public_database_access "$db_sg_id" "$DB_SG_NAME"

  validate_instances_private "$vpc_id"

  if [[ -n "${AURORA_WRITER_INSTANCE_IDENTIFIER:-}" ]]; then
    validate_aurora_private "$AURORA_WRITER_INSTANCE_IDENTIFIER"
  else
    log_warning "AURORA_WRITER_INSTANCE_IDENTIFIER is not set. Skipping Aurora public access validation."
  fi

  validate_instance_profile_exists "$EC2_INSTANCE_PROFILE_NAME"
  validate_role_attached_to_instance_profile "$EC2_INSTANCE_PROFILE_NAME" "$EC2_ROLE_NAME"

  log_success "Security validation completed successfully."
}

main "$@"