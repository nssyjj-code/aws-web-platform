#!/bin/bash

# -----------------------------------------------------------------------------
# 01-verify-environment.sh
#
# Validates the local workstation before deploying the AWS Production
# Web Platform.
#
# Verifies:
#   - Required CLI tools
#   - AWS credentials
#   - AWS account identity
#   - AWS region configuration
#   - Tool versions
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

export AWS_PAGER=""

# shellcheck source=../lib/logging.sh
source "$SCRIPT_DIR/../lib/logging.sh"

log_info "Verifying local deployment environment..."

required_commands=(
    aws
    git
    bash
    jq
)

for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_error "$command_name is not installed or not available in PATH."
        exit 1
    fi

    log_success "$command_name found."
done

log_info "Verifying AWS credentials..."

if ! aws sts get-caller-identity >/dev/null 2>&1; then
    log_error "AWS credentials are not configured or are invalid."

    echo
    echo "Run:"
    echo
    echo "    aws configure"
    echo

    exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
AWS_REGION="$(aws configure get region)"

if [[ -z "${AWS_REGION:-}" ]]; then
    log_error "No default AWS region configured."
    echo
    echo "Run:"
    echo
    echo "    aws configure"
    echo
    exit 1
fi

log_success "AWS credentials verified."

log_info "AWS Account : $ACCOUNT_ID"
log_info "IAM Identity: $CALLER_ARN"
log_info "AWS Region  : $AWS_REGION"

log_info "Tool Versions"
log_info "-------------"
log_info "AWS CLI : $(aws --version 2>&1)"
log_info "Git     : $(git --version)"
log_info "Bash    : ${BASH_VERSION}"
log_info "jq      : $(jq --version)"

log_success "Environment validation completed successfully."

exit 0