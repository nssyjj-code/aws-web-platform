#!/bin/bash

# scripts/lib/database.sh
# Shared RDS and Aurora database deployment helpers for the AWS Web Platform.

create_db_subnet_group() {
  local db_subnet_group_name="$1"
  local db_subnet_a_id="$2"
  local db_subnet_b_id="$3"

  aws_cli rds create-db-subnet-group \
    --db-subnet-group-name "$db_subnet_group_name" \
    --db-subnet-group-description "Private DB subnet group for $PROJECT_NAME" \
    --subnet-ids "$db_subnet_a_id" "$db_subnet_b_id" \
    --tags \
      "Key=Name,Value=$db_subnet_group_name" \
      "Key=Project,Value=$PROJECT_NAME" \
      "Key=Environment,Value=${ENVIRONMENT:-prod}" \
      "Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}" \
      "Key=Tier,Value=database" \
    --query "DBSubnetGroup.DBSubnetGroupName" \
    --output text
}

ensure_db_subnet_group() {
  local db_subnet_group_name="$1"
  local db_subnet_a_id="$2"
  local db_subnet_b_id="$3"
  local db_subnet_group

  db_subnet_group="$(find_db_subnet_group_by_name "$db_subnet_group_name")"

  if ! exists "$db_subnet_group"; then
    log_info "Creating DB subnet group: $db_subnet_group_name"
    db_subnet_group="$(create_db_subnet_group "$db_subnet_group_name" "$db_subnet_a_id" "$db_subnet_b_id")"
    log_success "Created DB subnet group: $db_subnet_group"
  else
    log_success "DB subnet group already exists: $db_subnet_group"
  fi

  echo "$db_subnet_group"
}

validate_database_credentials() {
  if [[ -z "${DB_MASTER_USERNAME:-}" || -z "${DB_MASTER_PASSWORD:-}" ]]; then
    log_error "DB_MASTER_USERNAME and DB_MASTER_PASSWORD must be set."
    echo
    echo "Example:"
    echo
    echo "  export DB_MASTER_USERNAME=\"adminuser\""
    echo "  export DB_MASTER_PASSWORD=\"ReplaceWithAStrongPassword123\""
    echo
    exit 1
  fi
}

create_aurora_cluster() {
  local cluster_id="$1"
  local subnet_group_name="$2"
  local db_sg_id="$3"

  validate_database_credentials

  aws_cli rds create-db-cluster \
    --db-cluster-identifier "$cluster_id" \
    --engine "$AURORA_ENGINE" \
    --database-name "$DB_NAME" \
    --master-username "$DB_MASTER_USERNAME" \
    --master-user-password "$DB_MASTER_PASSWORD" \
    --db-subnet-group-name "$subnet_group_name" \
    --vpc-security-group-ids "$db_sg_id" \
    --storage-encrypted \
    --backup-retention-period "$DB_BACKUP_RETENTION_DAYS" \
    --copy-tags-to-snapshot \
    --tags \
      "Key=Name,Value=$cluster_id" \
      "Key=Project,Value=$PROJECT_NAME" \
      "Key=Environment,Value=${ENVIRONMENT:-prod}" \
      "Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}" \
      "Key=Tier,Value=database" \
    --query "DBCluster.DBClusterIdentifier" \
    --output text
}

ensure_aurora_cluster() {
  local cluster_id="$1"
  local subnet_group_name="$2"
  local db_sg_id="$3"
  local cluster

  cluster="$(find_db_cluster_by_identifier "$cluster_id")"

  if ! exists "$cluster"; then
    log_info "Creating Aurora cluster: $cluster_id"
    cluster="$(create_aurora_cluster "$cluster_id" "$subnet_group_name" "$db_sg_id")"
    log_success "Created Aurora cluster: $cluster"
  else
    log_success "Aurora cluster already exists: $cluster"
  fi

  echo "$cluster"
}

wait_for_aurora_cluster() {
  local cluster_id="$1"

  log_info "Waiting for Aurora cluster to become available: $cluster_id"

  aws_cli rds wait db-cluster-available \
    --db-cluster-identifier "$cluster_id"

  log_success "Aurora cluster is available: $cluster_id"
}

create_aurora_instance() {
  local instance_id="$1"
  local cluster_id="$2"

  aws_cli rds create-db-instance \
    --db-instance-identifier "$instance_id" \
    --db-cluster-identifier "$cluster_id" \
    --engine "$AURORA_ENGINE" \
    --db-instance-class "$AURORA_INSTANCE_CLASS" \
    --no-publicly-accessible \
    --tags \
      "Key=Name,Value=$instance_id" \
      "Key=Project,Value=$PROJECT_NAME" \
      "Key=Environment,Value=${ENVIRONMENT:-prod}" \
      "Key=ManagedBy,Value=${MANAGED_BY:-aws-cli}" \
      "Key=Tier,Value=database" \
    --query "DBInstance.DBInstanceIdentifier" \
    --output text
}

ensure_aurora_instance() {
  local instance_id="$1"
  local cluster_id="$2"
  local instance

  instance="$(find_db_instance_by_identifier "$instance_id")"

  if ! exists "$instance"; then
    log_info "Creating Aurora instance: $instance_id"
    instance="$(create_aurora_instance "$instance_id" "$cluster_id")"
    log_success "Created Aurora instance: $instance"
  else
    log_success "Aurora instance already exists: $instance"
  fi

  echo "$instance"
}

wait_for_aurora_instance() {
  local instance_id="$1"

  log_info "Waiting for Aurora instance to become available: $instance_id"

  aws_cli rds wait db-instance-available \
    --db-instance-identifier "$instance_id"

  log_success "Aurora instance is available: $instance_id"
}