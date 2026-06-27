#!/bin/bash

# scripts/validation/validate-application.sh
# Validates application availability through the Application Load Balancer.

set -euo pipefail

export AWS_PAGER=""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../lib/bootstrap.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/bootstrap.sh"

ALB_NAME="${ALB_NAME:-${PROJECT_NAME}-alb}"
HEALTH_PATH="${TARGET_GROUP_HEALTH_CHECK_PATH:-/health.html}"

get_alb_dns_name() {
  aws_cli elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --query "LoadBalancers[0].DNSName" \
    --output text 2>/dev/null || echo "None"
}

validate_http_endpoint() {
  local url="$1"
  local expected_status="$2"
  local status_code

  status_code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || echo "000")"

  if [[ "$status_code" == "$expected_status" ]]; then
    log_success "Endpoint healthy: $url returned HTTP $status_code"
    return 0
  fi

  log_error "Endpoint unhealthy: $url returned HTTP $status_code, expected HTTP $expected_status"
  return 1
}

main() {
  validate_prerequisites

  log_info "Validating application availability through ALB: $ALB_NAME"

  local alb_dns
  alb_dns="$(get_alb_dns_name)"

  require_id "Application Load Balancer DNS name" "$ALB_NAME" "$alb_dns"

  local base_url="http://$alb_dns"
  local health_url="${base_url}${HEALTH_PATH}"

  log_info "Application URL: $base_url"
  log_info "Health URL: $health_url"

  validate_http_endpoint "$health_url" "200"
  validate_http_endpoint "$base_url" "200"

  log_success "Application validation completed successfully."
}

main "$@"