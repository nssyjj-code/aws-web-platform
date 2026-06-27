#!/bin/bash

# scripts/lib/load-balancing.sh
# Shared Elastic Load Balancing deployment helpers for the AWS Web Platform.

create_target_group() {
  local target_group_name="$1"
  local vpc_id="$2"
  local protocol="$3"
  local port="$4"
  local health_check_path="${5:-/health.html}"

  aws_cli elbv2 create-target-group \
    --name "$target_group_name" \
    --protocol "$protocol" \
    --port "$port" \
    --vpc-id "$vpc_id" \
    --target-type instance \
    --health-check-protocol HTTP \
    --health-check-path "$health_check_path" \
    --health-check-port traffic-port \
    --matcher HttpCode=200 \
    --tags \
      "Key=Name,Value=$target_group_name" \
      "Key=Project,Value=$PROJECT_NAME" \
      "Key=Environment,Value=${ENVIRONMENT:-prod}" \
      "Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}" \
      "Key=Tier,Value=load-balancing" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text
}

ensure_target_group() {
  local target_group_name="$1"
  local vpc_id="$2"
  local protocol="$3"
  local port="$4"
  local health_check_path="${5:-/health.html}"
  local target_group_arn

  target_group_arn="$(find_target_group_by_name "$target_group_name")"

  if ! exists "$target_group_arn"; then
    log_info "Creating target group: $target_group_name"

    target_group_arn="$(create_target_group \
      "$target_group_name" \
      "$vpc_id" \
      "$protocol" \
      "$port" \
      "$health_check_path")"

    log_success "Created target group: $target_group_arn"
  else
    log_success "Target group already exists: $target_group_name ($target_group_arn)"
  fi

  echo "$target_group_arn"
}

create_load_balancer() {
  local lb_name="$1"
  local public_subnet_a_id="$2"
  local public_subnet_b_id="$3"
  local alb_sg_id="$4"

  aws_cli elbv2 create-load-balancer \
    --name "$lb_name" \
    --subnets "$public_subnet_a_id" "$public_subnet_b_id" \
    --security-groups "$alb_sg_id" \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags \
      "Key=Name,Value=$lb_name" \
      "Key=Project,Value=$PROJECT_NAME" \
      "Key=Environment,Value=${ENVIRONMENT:-prod}" \
      "Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}" \
      "Key=Tier,Value=load-balancing" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text
}

ensure_load_balancer() {
  local lb_name="$1"
  local public_subnet_a_id="$2"
  local public_subnet_b_id="$3"
  local alb_sg_id="$4"
  local lb_arn

  lb_arn="$(find_load_balancer_by_name "$lb_name")"

  if ! exists "$lb_arn"; then
    log_info "Creating Application Load Balancer: $lb_name"

    lb_arn="$(create_load_balancer \
      "$lb_name" \
      "$public_subnet_a_id" \
      "$public_subnet_b_id" \
      "$alb_sg_id")"

    log_success "Created Application Load Balancer: $lb_arn"

    log_info "Waiting for Application Load Balancer to become active..."

    aws_cli elbv2 wait load-balancer-available \
      --load-balancer-arns "$lb_arn"

    log_success "Application Load Balancer is active: $lb_name"
  else
    log_success "Application Load Balancer already exists: $lb_name ($lb_arn)"
  fi

  echo "$lb_arn"
}

find_http_listener() {
  local lb_arn="$1"

  aws_cli elbv2 describe-listeners \
    --load-balancer-arn "$lb_arn" \
    --query "Listeners[?Protocol=='HTTP' && Port==\`80\`].ListenerArn | [0]" \
    --output text 2>/dev/null || echo "None"
}

create_http_listener() {
  local lb_arn="$1"
  local target_group_arn="$2"

  aws_cli elbv2 create-listener \
    --load-balancer-arn "$lb_arn" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="$target_group_arn" \
    --query "Listeners[0].ListenerArn" \
    --output text
}

ensure_http_listener() {
  local lb_arn="$1"
  local target_group_arn="$2"
  local listener_arn

  listener_arn="$(find_http_listener "$lb_arn")"

  if ! exists "$listener_arn"; then
    log_info "Creating HTTP listener on port 80"

    listener_arn="$(create_http_listener "$lb_arn" "$target_group_arn")"

    log_success "Created HTTP listener: $listener_arn"
  else
    log_success "HTTP listener already exists: $listener_arn"
  fi

  echo "$listener_arn"
}