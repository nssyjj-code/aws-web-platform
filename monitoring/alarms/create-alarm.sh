#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Missing configuration file: $CONFIG_FILE"
    exit 1
fi

# shellcheck source=/dev/null
# shellcheck disable=SC1091
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"
DASHBOARD_NAME="${PROJECT_NAME}-operations-dashboard"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

aws_cli() {
    aws --region "$AWS_REGION" "$@"
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
    if aws_cli cloudwatch describe-alarms \
        --alarm-names "$alarm" \
        --query "MetricAlarms[0].AlarmName" \
        --output text 2>/dev/null | grep -q "$alarm"; then

        log "Deleting alarm: $alarm"

        aws_cli cloudwatch delete-alarms \
            --alarm-names "$alarm"

    else
        log "Alarm not found: $alarm"
    fi
done

log "Deleting CloudWatch dashboard..."

if aws_cli cloudwatch list-dashboards \
    --query "DashboardEntries[?DashboardName=='${DASHBOARD_NAME}'].DashboardName" \
    --output text | grep -q "$DASHBOARD_NAME"; then

    aws_cli cloudwatch delete-dashboards \
        --dashboard-names "$DASHBOARD_NAME"

    log "Deleted dashboard: $DASHBOARD_NAME"

else
    log "Dashboard not found: $DASHBOARD_NAME"
fi

log "Monitoring cleanup completed successfully."