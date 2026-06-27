#!/bin/bash

# scripts/lib/validation.sh
# Shared validation helpers for AWS Web Platform automation scripts.

validate_aws_cli() {
  if ! command -v aws >/dev/null 2>&1; then
    log_error "AWS CLI is not installed."
    exit 1
  fi
}

validate_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is not installed."
    exit 1
  fi
}

validate_aws_credentials() {
  if ! aws_cli sts get-caller-identity >/dev/null 2>&1; then
    log_error "AWS credentials are invalid, expired, or not configured."
    exit 1
  fi
}

log_aws_identity() {
  local identity
  local account_id
  local caller_arn

  identity="$(aws_cli sts get-caller-identity --output json)"
  account_id="$(echo "$identity" | jq -r ".Account")"
  caller_arn="$(echo "$identity" | jq -r ".Arn")"

  log_info "AWS Account: $account_id"
  log_info "Authenticated Principal: $caller_arn"
  log_info "AWS Region: $AWS_REGION"
}

require_id() {
  local resource_type="$1"
  local resource_name="$2"
  local resource_id="$3"

  if ! exists "$resource_id"; then
    log_error "$resource_type not found: $resource_name"
    exit 1
  fi
}

validate_required_variable() {
  local variable_name="$1"
  local variable_value="${!variable_name:-}"

  if [[ -z "$variable_value" ]]; then
    log_error "Required variable is not set: $variable_name"
    exit 1
  fi
}

validate_required_variables() {
  local variable_name

  for variable_name in "$@"; do
    validate_required_variable "$variable_name"
  done
}

validate_prerequisites() {
  validate_aws_cli
  validate_jq
  validate_aws_credentials
  log_aws_identity
}