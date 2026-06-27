#!/bin/bash

# scripts/validation/verify-environment.sh
# Verifies core AWS Web Platform resources and health.

set -euo pipefail

export AWS_PAGER=""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../lib/bootstrap.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/bootstrap.sh"

require_state() {
  local name="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    log_error "$name verification failed. Expected '$expected', got '$actual'."
    exit 1
  fi

  log_success "$name verified: $actual"
}

run_optional_validation() {
  local script="$1"

  if [[ -x "$script" ]]; then
    log_info "Running supplemental validation: $(basename "$script")"
    "$script"
  else
    log_warning "Supplemental validation script missing or not executable: $script"
  fi
}

main() {
  log_info "Starting platform verification..."

  validate_prerequisites

  log_info "Verifying VPC..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"

  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "VPC verified: $vpc_id"

  log_info "Verifying Application Load Balancer..."

  local alb_state
  local alb_dns

  alb_state="$(aws_cli elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --query "LoadBalancers[0].State.Code" \
    --output text 2>/dev/null || echo "None")"

  require_state "ALB state" "$alb_state" "active"

  alb_dns="$(aws_cli elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --query "LoadBalancers[0].DNSName" \
    --output text)"

  log_success "ALB DNS verified: http://$alb_dns"

  log_info "Verifying Target Group..."

  local target_group_arn
  target_group_arn="$(find_target_group_by_name "$TARGET_GROUP_NAME")"

  require_id "Target Group" "$TARGET_GROUP_NAME" "$target_group_arn"

  log_success "Target Group verified: $target_group_arn"

  log_info "Verifying target health..."

  local healthy_targets
  healthy_targets="$(aws_cli elbv2 describe-target-health \
    --target-group-arn "$target_group_arn" \
    --query "TargetHealthDescriptions[?TargetHealth.State=='healthy'] | length(@)" \
    --output text)"

  if ! [[ "$healthy_targets" =~ ^[0-9]+$ ]] || (( healthy_targets < 1 )); then
    log_error "No healthy targets found in target group."

    aws_cli elbv2 describe-target-health \
      --target-group-arn "$target_group_arn" \
      --output table

    exit 1
  fi

  log_success "Healthy targets verified: $healthy_targets"

  log_info "Verifying Auto Scaling Group..."

  local asg_name_result
  local desired_capacity
  local in_service_instances

  asg_name_result="$(find_auto_scaling_group_by_name "$ASG_NAME")"

  require_id "Auto Scaling Group" "$ASG_NAME" "$asg_name_result"

  desired_capacity="$(aws_cli autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].DesiredCapacity" \
    --output text)"

  in_service_instances="$(aws_cli autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'] | length(@)" \
    --output text)"

  if ! [[ "$in_service_instances" =~ ^[0-9]+$ ]] || (( in_service_instances < 1 )); then
    log_error "Auto Scaling Group has no InService instances."
    exit 1
  fi

  log_success "ASG verified: $in_service_instances/$desired_capacity instances InService"

  log_info "Verifying Aurora cluster..."

  local aurora_status
  aurora_status="$(aws_cli rds describe-db-clusters \
    --db-cluster-identifier "$AURORA_CLUSTER_IDENTIFIER" \
    --query "DBClusters[0].Status" \
    --output text 2>/dev/null || echo "None")"

  require_state "Aurora cluster status" "$aurora_status" "available"

  log_info "Verifying Aurora writer instance..."

  local aurora_instance_status
  aurora_instance_status="$(aws_cli rds describe-db-instances \
    --db-instance-identifier "$AURORA_WRITER_INSTANCE_IDENTIFIER" \
    --query "DBInstances[0].DBInstanceStatus" \
    --output text 2>/dev/null || echo "None")"

  require_state "Aurora writer instance status" "$aurora_instance_status" "available"

  run_optional_validation "$ROOT_DIR/scripts/validation/validate-network.sh"
  run_optional_validation "$ROOT_DIR/scripts/validation/validate-security.sh"
  run_optional_validation "$ROOT_DIR/scripts/validation/validate-application.sh"

  echo
  echo "=================================================="
  echo "Platform Verification Summary"
  echo "=================================================="
  echo "VPC:                  $vpc_id"
  echo "ALB:                  $ALB_NAME"
  echo "Application URL:      http://$alb_dns"
  echo "Target Group:         $TARGET_GROUP_NAME"
  echo "Healthy Targets:      $healthy_targets"
  echo "Auto Scaling Group:   $ASG_NAME"
  echo "ASG Capacity:         $in_service_instances/$desired_capacity InService"
  echo "Aurora Cluster:       $AURORA_CLUSTER_IDENTIFIER"
  echo "Aurora Writer:        $AURORA_WRITER_INSTANCE_IDENTIFIER"
  echo "=================================================="
  echo

  log_success "Platform verification complete."
}

main "$@"