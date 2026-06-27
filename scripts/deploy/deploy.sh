#!/bin/bash

# scripts/deploy/deploy.sh
# Deploys the AWS Production Web Platform in dependency order.

set -euo pipefail

export AWS_PAGER=""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT_DIR

run_step() {
    local script="$1"

    echo
    echo "=================================================="
    echo "Running: $(basename "$script")"
    echo "=================================================="

    if [[ ! -f "$script" ]]; then
        echo "[ERROR] Missing script: $script"
        exit 1
    fi

    if [[ ! -x "$script" ]]; then
        echo "[ERROR] Script is not executable: $script"
        echo "Run: chmod +x \"$script\""
        exit 1
    fi

    "$script"

    echo
    echo "[SUCCESS] Completed: $(basename "$script")"
}

##################################################
# Environment Validation
##################################################

run_step "$ROOT_DIR/scripts/setup/01-verify-environment.sh"
run_step "$ROOT_DIR/scripts/setup/02-configure-aws.sh"

##################################################
# Networking
##################################################

run_step "$ROOT_DIR/scripts/deploy/01-create-vpc.sh"
run_step "$ROOT_DIR/scripts/deploy/02-create-subnets.sh"
run_step "$ROOT_DIR/scripts/deploy/03-create-internet-gateway.sh"
run_step "$ROOT_DIR/scripts/deploy/04-create-route-tables.sh"
run_step "$ROOT_DIR/scripts/deploy/05-create-nat-gateways.sh"

##################################################
# Security
##################################################

run_step "$ROOT_DIR/scripts/deploy/06-create-security-groups.sh"
run_step "$ROOT_DIR/scripts/deploy/07-create-ec2-iam-role.sh"

##################################################
# Compute
##################################################

run_step "$ROOT_DIR/scripts/deploy/08-create-launch-template.sh"
run_step "$ROOT_DIR/scripts/deploy/09-create-target-group.sh"
run_step "$ROOT_DIR/scripts/deploy/10-create-load-balancer.sh"
run_step "$ROOT_DIR/scripts/deploy/11-create-auto-scaling-group.sh"

##################################################
# Database
##################################################

run_step "$ROOT_DIR/scripts/deploy/12-create-rds-subnet-group.sh"
run_step "$ROOT_DIR/scripts/deploy/13-create-aurora-cluster.sh"
run_step "$ROOT_DIR/scripts/deploy/14-create-aurora-instance.sh"

##################################################
# Deployment Complete
##################################################

echo
echo "=================================================="
echo " AWS Production Web Platform deployment complete"
echo "=================================================="
echo
echo "Next recommended step:"
echo "  ./verify.sh"
echo