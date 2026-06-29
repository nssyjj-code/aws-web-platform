# Automation Design

## Overview

This document describes the automation architecture used to deploy, validate, and destroy the AWS Web Platform.

The platform is intentionally automated using AWS CLI and Bash to
demonstrate infrastructure lifecycle management, dependency handling,
resource discovery, and operational automation principles commonly
used in cloud engineering environments.

Automation goals include:

* Repeatable deployments
* Infrastructure consistency
* Dependency-aware provisioning
* Safe environment destruction
* Operational visibility
* Idempotent execution
* Troubleshooting support

This document describes the overall automation architecture, deployment workflow, shared libraries,
validation strategy, and infrastructure lifecycle used throughout the project.

---

## Automation Philosophy

The project treats infrastructure automation as code.

All infrastructure resources are:

* Version controlled
* Reproducible
* Script-driven
* Documented
* Validated after deployment

The objective is not only to deploy AWS resources but also to demonstrate understanding of infrastructure dependencies and lifecycle management.

---

## Repository Automation Structure

Automation is organized by lifecycle stage.

```text
.
├── deploy.sh
├── verify.sh
├── destroy.sh
│
├── config/
│   └── environment.conf
│
└── scripts/
    ├── setup/
    ├── deploy/
    ├── validation/
    ├── cleanup/
    └── lib/
```

---

## Root-Level Automation Wrappers

Three primary entry points exist at the repository root.

### deploy.sh

Deploys the entire platform.

Responsibilities:

* Environment validation
* AWS credential verification
* Dependency-aware deployment execution

Example:

```bash
./deploy.sh
```

---

### verify.sh

Validates deployed resources.

Responsibilities:

* Infrastructure verification
* Service health validation
* Deployment confirmation

Example:

```bash
./verify.sh
```

---

### destroy.sh

Removes deployed resources.

Responsibilities:

* Safe dependency removal
* Resource cleanup
* Cost control

Example:

```bash
./destroy.sh
```

---

## Shared Library Design

Reusable logic is centralized in:

```text
scripts/lib/
```

Examples:

| Library           | Purpose                            |
| ----------------- | ---------------------------------- |
| aws.sh            | Resource discovery helpers         |
| networking.sh     | VPC and subnet operations          |
| security.sh       | Security group management          |
| compute.sh        | EC2 and launch template operations |
| database.sh       | Aurora and RDS operations          |
| autoscaling.sh    | Auto Scaling operations            |
| load-balancing.sh | ALB and Target Group operations    |
| iam.sh            | IAM role and profile management    |
| validation.sh     | Environment validation             |
| logging.sh        | Consistent logging                 |

Benefits:

* Reduced code duplication
* Easier maintenance
* Consistent behavior
* Improved readability

---

## Configuration Management

Configuration values are separated from deployment logic.

Location:

```text
config/environment.conf
```

Examples:

* Region
* VPC CIDR
* Resource names
* Auto Scaling configuration
* Aurora configuration

Benefits:

* Centralized configuration
* Environment customization
* Improved maintainability
* Reduced hardcoding

Example:

```bash
source config/environment.conf
```

---

## Deployment Architecture

Infrastructure is deployed in dependency order.

```text
VPC
 │
 ▼
Subnets
 │
 ▼
Internet Gateway
 │
 ▼
Route Tables
 │
 ▼
NAT Gateways
 │
 ▼
Security Groups
 │
 ▼
IAM
 │
 ▼
Launch Template
 │
 ▼
Target Group
 │
 ▼
Application Load Balancer
 │
 ▼
Auto Scaling Group
 │
 ▼
Aurora Database
```

This ordering prevents AWS dependency failures.

---

## Why Dependency Ordering Matters

AWS resources frequently require previously created resources.

Examples:

### Subnets

Require:

```text
VPC
```

### Auto Scaling Groups

Require:

```text
Launch Template
Subnets
Target Group
```

### Aurora Clusters

Require:

```text
DB Subnet Group
Security Group
```

Failure to deploy in dependency order results in AWS API errors.

---

## Idempotency Strategy

Deployment automation is designed to be safely re-executed.

Each deployment script:

1. Searches for existing resources
2. Creates resources only when absent
3. Reuses existing resources when found
4. Returns resource identifiers consistently

Example workflow:

```text
Check Resource
      │
      ▼
Exists?
 │         │
Yes       No
 │         │
Reuse    Create
 │         │
 └────► Continue
```

Benefits:

* Safe redeployment
* Reduced deployment failures
* Easier troubleshooting
* Improved operational resilience

---

## Resource Discovery Strategy

Automation relies heavily on dynamic resource discovery.

Resources are located using tags and AWS APIs rather than hardcoded IDs.

Example:

```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=<resource-name>"
```

Benefits:

* Portability
* Reduced manual effort
* Easier recovery from partial deployments

---

## Error Handling Strategy

All scripts use strict Bash execution settings.

```bash
set -euo pipefail
```

### -e

Exit immediately when commands fail.

### -u

Fail when undefined variables are referenced.

### pipefail

Detect failures inside command pipelines.

Benefits:

* Earlier error detection
* More reliable automation
* Reduced silent failures

---

## Logging Strategy

All deployment operations use centralized logging helpers.

Log levels include:

```text
INFO
SUCCESS
ERROR
```

Example:

```text
[INFO] Creating VPC...
[SUCCESS] VPC created.
[ERROR] Resource creation failed.
```

Benefits:

* Consistent output
* Easier troubleshooting
* Better deployment visibility

---

## Validation Architecture

Validation occurs before and after deployment.

### Pre-Deployment Validation

Checks include:

* AWS CLI installed
* AWS credentials valid
* Configuration loaded

### Post-Deployment Validation

Checks include:

* VPC exists
* Subnets exist
* Route tables configured
* ALB operational
* Auto Scaling Group operational
* Aurora available

---

## Destruction Architecture

Cleanup follows reverse dependency order.

```text
Auto Scaling Group
 │
 ▼
Listeners
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
Launch Templates
 │
 ▼
IAM Resources
 │
 ▼
NAT Gateways
 │
 ▼
Route Tables
 │
 ▼
Security Groups
 │
 ▼
Subnets
 │
 ▼
Internet Gateway
 │
 ▼
VPC
```

This prevents AWS dependency violations.

---

## Example Dependency Failure

During development, Target Group deletion failed because an Application Load Balancer listener still referenced the Target Group.

AWS error:

```text
ResourceInUse:
Target group is currently in use by a listener or rule
```

Resolution:

```text
Delete Listener
      │
      ▼
Delete Target Group
```

This behavior was incorporated into the destruction automation.

---

## Production Evolution Path

This project intentionally uses AWS CLI automation to reinforce AWS service-level understanding.

A production evolution could include:

* Terraform
* CloudFormation
* GitHub Actions
* CI/CD pipelines
* Automated testing
* Drift detection
* Change approval workflows
* Multi-environment deployments

---

## Related Documentation

Additional automation references:

```text
docs/deployment/deployment-guide.md
docs/operations/testing-strategy.md
docs/operations/operational-runbook.md
```

---

## Design Goals

The automation framework was intentionally designed to demonstrate:

* Modular Bash automation
* Infrastructure lifecycle management
* Dependency-aware provisioning
* Idempotent deployments
* Operational validation
* Production-style automation patterns

---

## Summary

The automation architecture demonstrates complete infrastructure lifecycle management through:

* Provisioning
* Validation
* Monitoring
* Troubleshooting
* Cleanup

The design emphasizes repeatability, visibility, dependency awareness, and operational maintainability while demonstrating cloud engineering automation principles commonly found in production environments.
