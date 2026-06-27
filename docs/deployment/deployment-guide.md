# Deployment Guide

## Overview

This document describes the deployment process for the AWS Web Platform.

The platform provisions a production-style AWS environment using AWS CLI automation and Bash scripting.

The deployment workflow is designed to demonstrate:

* Infrastructure lifecycle management
* Dependency-aware provisioning
* Repeatable deployments
* Environment validation
* Safe infrastructure cleanup
* Operational troubleshooting

Infrastructure components deployed include:

* VPC networking
* Public and private subnets
* Internet Gateway
* NAT Gateways
* Route tables
* Security groups
* IAM roles and instance profiles
* Application Load Balancer
* Target Groups
* Launch Templates
* Auto Scaling Groups
* EC2 application instances
* Aurora MySQL database resources

---

# Deployment Architecture

The deployment process follows a layered architecture.

```text
Repository Root
       │
       ▼
deploy.sh
       │
       ▼
Setup Validation
       │
       ▼
Infrastructure Deployment
       │
       ▼
Environment Verification
```

The deployment process uses dependency-aware execution to ensure AWS resources are created in the correct order.

---

# Prerequisites

Before deployment, verify the following requirements.

Required:

* AWS account
* AWS CLI v2
* Git
* Bash shell
* Appropriate IAM permissions

---

## Required Tools

| Tool    | Required Version |
| ------- | ---------------- |
| AWS CLI | v2.x             |
| Git     | 2.x              |
| Bash    | 4.x or newer     |

Validate installations:

```bash
aws --version
git --version
bash --version
```

Expected output:

```text
aws-cli/2.x
git version 2.x
GNU bash 4.x or newer
```

---

# Repository Setup

Clone the repository:

```bash
git clone https://github.com/nssyjj-code/aws-web-platform.git

cd aws-web-platform
```

Verify repository structure:

```text
.
├── deploy.sh
├── verify.sh
├── destroy.sh
├── config/
├── scripts/
├── docs/
└── policies/
```

---

# AWS Authentication

Configure AWS credentials:

```bash
aws configure
```

Validate authentication:

```bash
aws sts get-caller-identity
```

Confirm:

* Correct AWS account
* Correct IAM identity
* Expected permissions

Deployment should not proceed until the active AWS identity is verified.

---

# Required Environment Variables

Database credentials are intentionally excluded from source control.

Before deployment:

```bash
export DB_MASTER_USERNAME="adminuser"
export DB_MASTER_PASSWORD="ReplaceWithAStrongPassword123"
```

Verify:

```bash
test -n "$DB_MASTER_USERNAME" && echo "DB username is set"
test -n "$DB_MASTER_PASSWORD" && echo "DB password is set"
```

These values are consumed during Aurora cluster creation and are never stored within:

* Source control
* Deployment scripts
* Configuration files

Production environments should use AWS Secrets Manager rather than manually exported variables.

---

# Environment Configuration

Deployment configuration is stored in:

```text
config/environment.conf
```

Examples:

* AWS Region
* Resource names
* CIDR allocations
* Auto Scaling settings
* Aurora settings
* Environment naming conventions

Review configuration values before deployment.

Deployment scripts should never be modified to change environment settings.

Configuration should remain externalized.

---

# Cost Awareness

This platform provisions production-style AWS infrastructure.

Primary cost drivers include:

* NAT Gateways
* Aurora MySQL
* EC2 instances
* Application Load Balancer

Development environments should be destroyed when not actively used.

Cleanup command:

```bash
./destroy.sh
```

Additional cost information:

```text
docs/governance/cost-optimization.md
```

---

# Deployment Execution

Start deployment:

```bash
./deploy.sh
```

The deployment wrapper automatically executes:

```text
Setup Validation
      │
      ▼
Infrastructure Deployment
      │
      ▼
Resource Verification
```

No individual deployment scripts need to be executed manually.

---

# Deployment Stages

## Stage 1 – Environment Validation

Validates:

* AWS CLI installation
* AWS credentials
* Configuration files
* Repository structure

Scripts:

```text
scripts/setup/01-verify-environment.sh
scripts/setup/02-configure-aws.sh
```

---

## Stage 2 – Network Foundation

Creates:

* VPC
* Public subnets
* Private application subnets
* Private database subnets

Resources:

```text
VPC
Subnets
Availability Zones
```

---

## Stage 3 – Network Routing

Creates:

* Internet Gateway
* Elastic IPs
* NAT Gateways
* Route tables
* Route associations

Expected routing:

Public:

```text
0.0.0.0/0 → Internet Gateway
```

Private Application:

```text
0.0.0.0/0 → NAT Gateway
```

---

## Stage 4 – Security Layer

Creates:

* ALB Security Group
* Application Security Group
* Database Security Group

Traffic model:

```text
Internet
    │
    ▼
ALB
    │
    ▼
Application Tier
    │
    ▼
Database Tier
```

---

## Stage 5 – IAM Configuration

Creates:

* EC2 IAM Role
* Instance Profile
* Systems Manager permissions

Benefits:

* No embedded credentials
* Secure AWS service access
* Session Manager administration

---

## Stage 6 – Compute Deployment

Creates:

* Launch Template
* Auto Scaling Group
* EC2 instances

Validation:

```bash
aws autoscaling describe-auto-scaling-groups
```

Expected:

```text
LifecycleState = InService
HealthStatus = Healthy
```

---

## Stage 7 – Load Balancer Deployment

Creates:

* Application Load Balancer
* Target Group
* Listener

Validation:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

Expected:

```text
TargetHealth.State = healthy
```

---

## Stage 8 – Database Deployment

Creates:

* Aurora subnet group
* Aurora cluster
* Aurora writer instance

Validation:

```bash
aws rds describe-db-clusters
```

Expected:

```text
Status = available
```

---

# Post-Deployment Verification

Run:

```bash
./verify.sh
```

Verification checks:

## Networking

* VPC exists
* Subnets exist
* Route tables configured

## Compute

* Auto Scaling Group active
* Instances healthy
* Target Group healthy

## Database

* Aurora cluster available
* Aurora instance available

## Security

* Private application instances
* Private database resources
* Security groups configured correctly

---

# Deployment Troubleshooting

Common issues:

| Error               | Cause                        |
| ------------------- | ---------------------------- |
| AccessDenied        | Missing IAM permissions      |
| DependencyViolation | Resource dependency conflict |
| LimitExceeded       | AWS quota exceeded           |
| InvalidParameter    | Configuration issue          |
| AuthFailure         | AWS authentication issue     |

Troubleshooting process:

1. Review deployment logs
2. Identify failing AWS service
3. Verify configuration
4. Verify permissions
5. Correct issue
6. Re-run deployment

Because the deployment is idempotent, rerunning deployment after correcting an issue is generally safe.

---

# Rollback Procedure

Remove the environment:

```bash
./destroy.sh
```

Cleanup removes resources using reverse dependency ordering.

Examples:

```text
Auto Scaling Group
      │
      ▼
Load Balancer
      │
      ▼
Target Group
      │
      ▼
Aurora Resources
      │
      ▼
Networking Resources
```

This prevents AWS dependency violations.

---

# Production Evolution

Future enhancements could include:

* Terraform
* CloudFormation
* GitHub Actions CI/CD
* Automated testing
* Drift detection
* Secrets Manager integration
* Multi-environment deployments
* Change approval workflows
* Blue/Green deployments

---

# Related Documentation

Additional deployment references:

```text
docs/deployment/automation-design.md
docs/operations/testing-strategy.md
docs/operations/operational-runbook.md
```

---

# Summary

The deployment process demonstrates a complete infrastructure lifecycle including:

* Validation
* Provisioning
* Verification
* Troubleshooting
* Cleanup

The automation emphasizes repeatability, operational visibility, dependency awareness, and production-style cloud deployment practices while remaining practical for development and portfolio use.