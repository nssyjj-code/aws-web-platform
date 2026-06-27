#!/bin/bash

# -----------------------------------------------------------------------------
# 02-configure-aws.sh
#
# Verifies the local AWS CLI configuration and authenticated AWS identity
# before infrastructure deployment.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

export AWS_PAGER=""

# shellcheck source=../lib/logging.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/logging.sh"

readonly AWS_REGION="${AWS_REGION:-us-east-1}"
readonly AWS_PROFILE_NAME="${AWS_PROFILE:-}"

log_info "Checking AWS CLI configuration..."

for command_name in aws jq; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_error "$command_name is not installed."
        exit 1
    fi
done

AWS_ARGS=(--region "$AWS_REGION")

if [[ -n "$AWS_PROFILE_NAME" ]]; then
    AWS_ARGS+=(--profile "$AWS_PROFILE_NAME")
fi

if ! IDENTITY="$(aws sts get-caller-identity "${AWS_ARGS[@]}" --output json 2>/dev/null)"; then
    log_error "AWS credentials are not configured or are invalid."

    echo
    echo "Configure credentials with:"
    echo

    if [[ -n "$AWS_PROFILE_NAME" ]]; then
        echo "    aws configure --profile $AWS_PROFILE_NAME"
    else
        echo "    aws configure"
    fi

    echo
    echo "Recommended region:"
    echo
    echo "    $AWS_REGION"
    echo

    exit 1
fi

ACCOUNT_ID="$(echo "$IDENTITY" | jq -r '.Account')"
CALLER_ARN="$(echo "$IDENTITY" | jq -r '.Arn')"

readonly ACCOUNT_ID
readonly CALLER_ARN

log_success "AWS CLI credentials verified."

if [[ -n "$AWS_PROFILE_NAME" ]]; then
    log_info "AWS Profile : $AWS_PROFILE_NAME"
else
    log_info "AWS Profile : default credential chain"
fi

log_info "AWS Region  : $AWS_REGION"
log_info "AWS Account : $ACCOUNT_ID"
log_info "IAM Identity: $CALLER_ARN"

log_success "AWS CLI configuration validated successfully."

exit 0