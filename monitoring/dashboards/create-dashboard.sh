#!/bin/bash

# Deletes CloudWatch alarms and dashboards created for AWS Web Platform monitoring.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Missing configuration file: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=../../config/environment.conf
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"

required_vars=(
  PROJECT_NAME
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required variable is not set: $var"
    exit 1
  fi
done

DASHBOARD_NAME="${PROJECT_NAME}-operations-dashboard"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

aws_cli() {
  aws --region "$AWS_REGION" "$@"
}

alarm_exists() {
  local alarm_name="$1"

  aws_cli cloudwatch describe-alarms \
    --alarm-names "$alarm_name" \
    --query "MetricAlarms[0].AlarmName" \
    --output text 2>/dev/null | grep -Fxq "$alarm_name"
}

dashboard_exists() {
  local dashboard_name="$1"

  aws_cli cloudwatch list-dashboards \
    --query "DashboardEntries[?DashboardName=='${dashboard_name}'].DashboardName" \
    --output text 2>/dev/null | grep -Fxq "$dashboard_name"
}

log "Deleting CloudWatch alarms..."

ALARMS=(
  "${PROJECT_NAME}-alb-unhealthy-targets"
  "${PROJECT_NAME}-alb-5xx-errors"
  "${PROJECT_NAME}-target-5xx-errors"
  "${PROJECT_NAME}-alb-high-latency"
  "${PROJECT_NAME}-asg-capacity-mismatch"
  "${PROJECT_NAME}-aurora-high-cpu"
  "${PROJECT_NAME}-aurora-high-connections"
)

for alarm in "${ALARMS[@]}"; do
  if alarm_exists "$alarm"; then
    log "Deleting alarm: $alarm"

    aws_cli cloudwatch delete-alarms \
      --alarm-names "$alarm"

    log "Deleted alarm: $alarm"
  else
    log "Alarm not found: $alarm"
  fi
done

log "Deleting CloudWatch dashboard..."

if dashboard_exists "$DASHBOARD_NAME"; then
  aws_cli cloudwatch delete-dashboards \
    --dashboard-names "$DASHBOARD_NAME"

  log "Deleted dashboard: $DASHBOARD_NAME"
else
  log "Dashboard not found: $DASHBOARD_NAME"
fi

log "Monitoring cleanup completed successfully."