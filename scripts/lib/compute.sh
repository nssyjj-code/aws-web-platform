#!/bin/bash

# scripts/lib/compute.sh
# Shared EC2 compute deployment helpers for the AWS Web Platform.

build_launch_template_data() {
  local ami_id="$1"
  local instance_type="$2"
  local security_group_id="$3"
  local instance_profile_name="$4"
  local user_data_file="$5"
  local user_data_encoded

  user_data_encoded="$(base64 -w 0 "$user_data_file")"

  cat <<EOF
{
  "ImageId": "$ami_id",
  "InstanceType": "$instance_type",
  "IamInstanceProfile": {
    "Name": "$instance_profile_name"
  },
  "SecurityGroupIds": [
    "$security_group_id"
  ],
  "MetadataOptions": {
    "HttpTokens": "required",
    "HttpEndpoint": "enabled"
  },
  "Monitoring": {
    "Enabled": true
  },
  "UserData": "$user_data_encoded",
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "$PROJECT_NAME-app-instance"},
        {"Key": "Project", "Value": "$PROJECT_NAME"},
        {"Key": "Environment", "Value": "$ENVIRONMENT"},
        {"Key": "ManagedBy", "Value": "${MANAGED_BY:-aws-cli}"},
        {"Key": "Tier", "Value": "app"}
      ]
    }
  ]
}
EOF
}

create_launch_template() {
  local launch_template_name="$1"
  local ami_id="$2"
  local instance_type="$3"
  local security_group_id="$4"
  local instance_profile_name="$5"
  local user_data_file="$6"
  local launch_template_data

  launch_template_data="$(build_launch_template_data \
    "$ami_id" \
    "$instance_type" \
    "$security_group_id" \
    "$instance_profile_name" \
    "$user_data_file")"

  aws_cli ec2 create-launch-template \
    --launch-template-name "$launch_template_name" \
    --version-description "Initial application server launch template" \
    --launch-template-data "$launch_template_data" \
    --query "LaunchTemplate.LaunchTemplateId" \
    --output text
}

create_launch_template_version() {
  local launch_template_name="$1"
  local ami_id="$2"
  local instance_type="$3"
  local security_group_id="$4"
  local instance_profile_name="$5"
  local user_data_file="$6"
  local launch_template_data

  launch_template_data="$(build_launch_template_data \
    "$ami_id" \
    "$instance_type" \
    "$security_group_id" \
    "$instance_profile_name" \
    "$user_data_file")"

  aws_cli ec2 create-launch-template-version \
    --launch-template-name "$launch_template_name" \
    --version-description "Updated application server launch template" \
    --launch-template-data "$launch_template_data" \
    --query "LaunchTemplateVersion.VersionNumber" \
    --output text
}

set_default_launch_template_version() {
  local launch_template_name="$1"
  local version_number="$2"

  aws_cli ec2 modify-launch-template \
    --launch-template-name "$launch_template_name" \
    --default-version "$version_number" >/dev/null
}

ensure_launch_template() {
  local launch_template_name="$1"
  local ami_id="$2"
  local instance_type="$3"
  local security_group_id="$4"
  local instance_profile_name="$5"
  local user_data_file="$6"
  local launch_template_id
  local version_number

  launch_template_id="$(find_launch_template_by_name "$launch_template_name")"

  if ! exists "$launch_template_id"; then
    log_info "Creating launch template: $launch_template_name" >&2

    launch_template_id="$(create_launch_template \
      "$launch_template_name" \
      "$ami_id" \
      "$instance_type" \
      "$security_group_id" \
      "$instance_profile_name" \
      "$user_data_file")"

    log_success "Created launch template $launch_template_name: $launch_template_id" >&2
  else
    log_info "Launch template already exists: $launch_template_name ($launch_template_id)" >&2
    log_info "Creating new launch template version with latest user data..." >&2

    version_number="$(create_launch_template_version \
      "$launch_template_name" \
      "$ami_id" \
      "$instance_type" \
      "$security_group_id" \
      "$instance_profile_name" \
      "$user_data_file")"

    set_default_launch_template_version "$launch_template_name" "$version_number"

    log_success "Created launch template version $version_number and set it as default." >&2
  fi

  echo "$launch_template_id"
}