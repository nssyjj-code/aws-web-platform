#!/bin/bash

# scripts/lib/iam.sh
# Shared IAM deployment helpers for the AWS Web Platform.

find_iam_role() {
  local role_name="$1"

  aws iam get-role \
    --role-name "$role_name" \
    --query "Role.RoleName" \
    --output text 2>/dev/null || echo "None"
}

create_ec2_role() {
  local role_name="$1"
  local trust_policy_path="$2"

  aws iam create-role \
    --role-name "$role_name" \
    --assume-role-policy-document "file://$trust_policy_path" \
    --description "EC2 role for $PROJECT_NAME application instances" \
    --tags \
      "Key=Project,Value=$PROJECT_NAME" \
      "Key=Environment,Value=${ENVIRONMENT:-prod}" \
      "Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}" \
    --query "Role.RoleName" \
    --output text
}

ensure_ec2_role() {
  local role_name="$1"
  local trust_policy_path="$2"
  local role

  role="$(find_iam_role "$role_name")"

  if ! exists "$role"; then
    log_info "Creating IAM role: $role_name"
    role="$(create_ec2_role "$role_name" "$trust_policy_path")"
    log_success "Created IAM role: $role"
  else
    log_success "IAM role already exists: $role"
  fi

  echo "$role"
}

ensure_role_policy_attachment() {
  local role_name="$1"
  local policy_arn="$2"

  if aws iam list-attached-role-policies \
    --role-name "$role_name" \
    --query "AttachedPolicies[?PolicyArn=='$policy_arn'].PolicyArn" \
    --output text 2>/dev/null | grep -Fxq "$policy_arn"; then
    log_success "Policy already attached to role: $policy_arn"
    return 0
  fi

  log_info "Attaching policy to role: $policy_arn"

  aws iam attach-role-policy \
    --role-name "$role_name" \
    --policy-arn "$policy_arn"

  log_success "Attached policy to role: $policy_arn"
}

find_instance_profile() {
  local instance_profile_name="$1"

  aws iam get-instance-profile \
    --instance-profile-name "$instance_profile_name" \
    --query "InstanceProfile.InstanceProfileName" \
    --output text 2>/dev/null || echo "None"
}

create_instance_profile() {
  local instance_profile_name="$1"

  aws iam create-instance-profile \
    --instance-profile-name "$instance_profile_name" \
    --tags \
      "Key=Project,Value=$PROJECT_NAME" \
      "Key=Environment,Value=${ENVIRONMENT:-prod}" \
      "Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}" \
    --query "InstanceProfile.InstanceProfileName" \
    --output text
}

ensure_instance_profile() {
  local instance_profile_name="$1"
  local instance_profile

  instance_profile="$(find_instance_profile "$instance_profile_name")"

  if ! exists "$instance_profile"; then
    log_info "Creating IAM instance profile: $instance_profile_name"
    instance_profile="$(create_instance_profile "$instance_profile_name")"
    log_success "Created IAM instance profile: $instance_profile"
  else
    log_success "IAM instance profile already exists: $instance_profile"
  fi

  echo "$instance_profile"
}

ensure_role_in_instance_profile() {
  local instance_profile_name="$1"
  local role_name="$2"

  if aws iam get-instance-profile \
    --instance-profile-name "$instance_profile_name" \
    --query "InstanceProfile.Roles[?RoleName=='$role_name'].RoleName" \
    --output text 2>/dev/null | grep -Fxq "$role_name"; then
    log_success "Role already in instance profile: $role_name"
    return 0
  fi

  log_info "Adding role to instance profile: $role_name"

  aws iam add-role-to-instance-profile \
    --instance-profile-name "$instance_profile_name" \
    --role-name "$role_name"

  log_success "Added role to instance profile: $role_name"

  log_info "Waiting briefly for IAM instance profile propagation..."
  sleep 10
}