#!/bin/bash

# scripts/deploy/06-create-security-groups.sh
# Creates layered security groups for the AWS Web Platform.

set -euo pipefail

export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/environment.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Missing config file: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=../../config/environment.conf
# shellcheck disable=SC1091
source "$CONFIG_FILE"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-web-platform}"

VPC_NAME="${VPC_NAME:-$PROJECT_NAME-vpc}"
ALB_SG_NAME="${ALB_SG_NAME:-$PROJECT_NAME-alb-sg}"
APP_SG_NAME="${APP_SG_NAME:-$PROJECT_NAME-app-sg}"
DB_SG_NAME="${DB_SG_NAME:-$PROJECT_NAME-db-sg}"
ENABLE_HTTPS="${ENABLE_HTTPS:-false}"

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

# shellcheck source=../lib/aws.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/aws.sh"

# shellcheck source=../lib/validation.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/validation.sh"

# shellcheck source=../lib/security.sh
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/security.sh"

main() {
  validate_prerequisites

  log_info "Retrieving VPC ID..."

  local vpc_id
  vpc_id="$(find_vpc_by_name "$VPC_NAME")"
  require_id "VPC" "$VPC_NAME" "$vpc_id"

  log_success "Found VPC: $vpc_id"

  log_info "Ensuring security groups exist..."

  local alb_sg_id
  local app_sg_id
  local db_sg_id

  alb_sg_id="$(ensure_security_group "$vpc_id" "$ALB_SG_NAME" "Allows public web traffic to the Application Load Balancer" "alb")"
  app_sg_id="$(ensure_security_group "$vpc_id" "$APP_SG_NAME" "Allows application traffic from the ALB only" "app")"
  db_sg_id="$(ensure_security_group "$vpc_id" "$DB_SG_NAME" "Allows database traffic from the application tier only" "database")"

  require_id "Security Group" "$ALB_SG_NAME" "$alb_sg_id"
  require_id "Security Group" "$APP_SG_NAME" "$app_sg_id"
  require_id "Security Group" "$DB_SG_NAME" "$db_sg_id"

  log_success "Security group ready: $ALB_SG_NAME ($alb_sg_id)"
  log_success "Security group ready: $APP_SG_NAME ($app_sg_id)"
  log_success "Security group ready: $DB_SG_NAME ($db_sg_id)"

  log_info "Configuring ALB security group rules..."

  ensure_ingress_cidr_rule "$alb_sg_id" "tcp" 80 80 "0.0.0.0/0" "Allow HTTP from internet"

  if [[ "$ENABLE_HTTPS" == "true" ]]; then
    ensure_ingress_cidr_rule "$alb_sg_id" "tcp" 443 443 "0.0.0.0/0" "Allow HTTPS from internet"
  else
    log_info "HTTPS ingress disabled. Set ENABLE_HTTPS=true to allow port 443."
  fi

  log_info "Configuring application security group rules..."

  ensure_ingress_sg_rule "$app_sg_id" "tcp" 80 80 "$alb_sg_id" "Allow HTTP from ALB"

  log_info "Configuring database security group rules..."

  ensure_ingress_sg_rule "$db_sg_id" "tcp" 3306 3306 "$app_sg_id" "Allow MySQL/Aurora from app tier"

  log_success "Security groups created and configured successfully."
}

main "$@"