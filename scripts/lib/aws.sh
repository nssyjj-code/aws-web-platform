#!/bin/bash

# scripts/lib/aws.sh
# Shared AWS CLI helpers and resource lookup functions for the AWS Web Platform.

aws_cli() {
  aws --region "$AWS_REGION" "$@"
}

exists() {
  [[ -n "${1:-}" && "$1" != "None" && "$1" != "null" ]]
}

find_vpc_by_name() {
  local vpc_name="$1"

  aws_cli ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=$vpc_name" \
    --query "Vpcs[0].VpcId" \
    --output text 2>/dev/null || echo "None"
}

find_igw_by_vpc_id() {
  local vpc_id="$1"

  aws_cli ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text 2>/dev/null || echo "None"
}

find_subnet_by_name() {
  local vpc_id="$1"
  local subnet_name="$2"

  aws_cli ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=$subnet_name" \
    --query "Subnets[0].SubnetId" \
    --output text 2>/dev/null || echo "None"
}

find_route_table_by_name() {
  local vpc_id="$1"
  local route_table_name="$2"

  aws_cli ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=$route_table_name" \
    --query "RouteTables[0].RouteTableId" \
    --output text 2>/dev/null || echo "None"
}

find_eip_allocation_by_name() {
  local eip_name="$1"

  aws_cli ec2 describe-addresses \
    --filters "Name=tag:Name,Values=$eip_name" \
    --query "Addresses[0].AllocationId" \
    --output text 2>/dev/null || echo "None"
}

find_nat_gateway_by_name() {
  local nat_gateway_name="$1"

  aws_cli ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=$nat_gateway_name" "Name=state,Values=pending,available,deleting" \
    --query "NatGateways[0].NatGatewayId" \
    --output text 2>/dev/null || echo "None"
}

find_security_group_by_name() {
  local vpc_id="$1"
  local security_group_name="$2"

  aws_cli ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=$security_group_name" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None"
}

find_latest_amazon_linux_2023_ami() {
  aws_cli ssm get-parameter \
    --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" \
    --query "Parameter.Value" \
    --output text 2>/dev/null || echo "None"
}

find_launch_template_by_name() {
  local launch_template_name="$1"

  aws_cli ec2 describe-launch-templates \
    --launch-template-names "$launch_template_name" \
    --query "LaunchTemplates[0].LaunchTemplateId" \
    --output text 2>/dev/null || echo "None"
}

find_auto_scaling_group_by_name() {
  local asg_name="$1"

  aws_cli autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$asg_name" \
    --query "AutoScalingGroups[0].AutoScalingGroupName" \
    --output text 2>/dev/null || echo "None"
}

find_load_balancer_by_name() {
  local alb_name="$1"

  aws_cli elbv2 describe-load-balancers \
    --names "$alb_name" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text 2>/dev/null || echo "None"
}

find_target_group_by_name() {
  local target_group_name="$1"

  aws_cli elbv2 describe-target-groups \
    --names "$target_group_name" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null || echo "None"
}

find_db_subnet_group_by_name() {
  local db_subnet_group_name="$1"

  aws_cli rds describe-db-subnet-groups \
    --db-subnet-group-name "$db_subnet_group_name" \
    --query "DBSubnetGroups[0].DBSubnetGroupName" \
    --output text 2>/dev/null || echo "None"
}

find_db_cluster_by_identifier() {
  local cluster_identifier="$1"

  aws_cli rds describe-db-clusters \
    --db-cluster-identifier "$cluster_identifier" \
    --query "DBClusters[0].DBClusterIdentifier" \
    --output text 2>/dev/null || echo "None"
}

find_db_instance_by_identifier() {
  local instance_identifier="$1"

  aws_cli rds describe-db-instances \
    --db-instance-identifier "$instance_identifier" \
    --query "DBInstances[0].DBInstanceIdentifier" \
    --output text 2>/dev/null || echo "None"
}