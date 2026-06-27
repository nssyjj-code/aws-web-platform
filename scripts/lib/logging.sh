#!/bin/bash

# scripts/lib/logging.sh
# Shared logging helpers for AWS Web Platform automation scripts.

log_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
  echo "[$(log_timestamp)] [INFO] $*" >&2
}

log_success() {
  echo "[$(log_timestamp)] [SUCCESS] $*" >&2
}

log_warning() {
  echo "[$(log_timestamp)] [WARNING] $*" >&2
}

log_error() {
  echo "[$(log_timestamp)] [ERROR] $*" >&2
}