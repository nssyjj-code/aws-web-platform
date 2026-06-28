#!/bin/bash

# Creates a CloudWatch operations dashboard for ALB, Auto Scaling, EC2, and Aurora metrics.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Missing config file: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=/dev/null
# shellcheck disable=SC1091
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"

required_vars=(
  PROJECT_NAME
  ALB_NAME
  TARGET_GROUP_NAME
  ASG_NAME
  AURORA_WRITER_INSTANCE_IDENTIFIER
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required variable is not set: $var"
    exit 1
  fi
done

DASHBOARD_NAME="${PROJECT_NAME}-operations-dashboard"
DASHBOARD_BODY_FILE="$(mktemp)"

cleanup() {
  rm -f "$DASHBOARD_BODY_FILE"
}

trap cleanup EXIT

aws_cli() {
  aws --region "$AWS_REGION" "$@"
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

get_alb_dimension() {
  local alb_arn

  alb_arn=$(aws_cli elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)

  if [[ -z "$alb_arn" || "$alb_arn" == "None" ]]; then
    echo "ERROR: Unable to discover ALB ARN for: $ALB_NAME" >&2
    exit 1
  fi

  echo "$alb_arn" | awk -F'loadbalancer/' '{print $2}'
}

get_target_group_dimension() {
  local tg_arn

  tg_arn=$(aws_cli elbv2 describe-target-groups \
    --names "$TARGET_GROUP_NAME" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)

  if [[ -z "$tg_arn" || "$tg_arn" == "None" ]]; then
    echo "ERROR: Unable to discover target group ARN for: $TARGET_GROUP_NAME" >&2
    exit 1
  fi

  echo "$tg_arn" | awk -F':targetgroup/' '{print "targetgroup/" $2}'
}

log "Discovering CloudWatch dashboard dimensions..."

LOAD_BALANCER_DIMENSION="$(get_alb_dimension)"
TARGET_GROUP_DIMENSION="$(get_target_group_dimension)"

cat > "$DASHBOARD_BODY_FILE" <<EOF
{
  "widgets": [
    {
      "type": "text",
      "x": 0,
      "y": 0,
      "width": 24,
      "height": 2,
      "properties": {
        "markdown": "# ${PROJECT_NAME} Operations Dashboard\\nProduction-style monitoring view for ALB, Auto Scaling, EC2, and Aurora."
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 2,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB Request Count",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 60,
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${LOAD_BALANCER_DIMENSION}", { "stat": "Sum" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 2,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB Target Response Time",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 60,
        "metrics": [
          [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${LOAD_BALANCER_DIMENSION}", { "stat": "Average" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 8,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB 5XX Errors",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 60,
        "metrics": [
          [ "AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", "${LOAD_BALANCER_DIMENSION}", { "stat": "Sum" } ],
          [ ".", "HTTPCode_Target_5XX_Count", ".", ".", { "stat": "Sum" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 8,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Target Group Health",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 60,
        "metrics": [
          [ "AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "${TARGET_GROUP_DIMENSION}", "LoadBalancer", "${LOAD_BALANCER_DIMENSION}", { "stat": "Average" } ],
          [ ".", "UnHealthyHostCount", ".", ".", ".", ".", { "stat": "Maximum" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 14,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Auto Scaling Capacity",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 60,
        "metrics": [
          [ "AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "${ASG_NAME}", { "stat": "Average" } ],
          [ ".", "GroupInServiceInstances", ".", ".", { "stat": "Average" } ],
          [ ".", "GroupPendingInstances", ".", ".", { "stat": "Average" } ],
          [ ".", "GroupTerminatingInstances", ".", ".", { "stat": "Average" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 14,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Aurora Writer CPU",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "metrics": [
          [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${AURORA_WRITER_INSTANCE_IDENTIFIER}", { "stat": "Average" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 20,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Aurora Database Connections",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "metrics": [
          [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${AURORA_WRITER_INSTANCE_IDENTIFIER}", { "stat": "Average" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 20,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Aurora Read and Write Latency",
        "region": "${AWS_REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "metrics": [
          [ "AWS/RDS", "ReadLatency", "DBInstanceIdentifier", "${AURORA_WRITER_INSTANCE_IDENTIFIER}", { "stat": "Average" } ],
          [ ".", "WriteLatency", ".", ".", { "stat": "Average" } ]
        ]
      }
    }
  ]
}
EOF

log "Creating CloudWatch dashboard: $DASHBOARD_NAME"

aws_cli cloudwatch put-dashboard \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body "file://$DASHBOARD_BODY_FILE"

log "Dashboard created successfully: $DASHBOARD_NAME"