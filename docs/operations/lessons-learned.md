# Project Retrospective

## Overview

This document captures key technical, operational, and architectural lessons learned while designing, 
deploying, troubleshooting, and refining the AWS Web Platform.

The project evolved from a collection of AWS CLI scripts into a dependency-aware deployment 
framework capable of provisioning and validating a multi-tier AWS environment.

Many of the lessons documented here were discovered through troubleshooting real deployment failures, 
dependency issues, configuration errors, and operational testing.

The goal of this document is to highlight engineering insights gained throughout 
the project rather than simply documenting successful outcomes.

---

## Purpose

This retrospective captures the technical, architectural, and operational insights gained throughout the development of the AWS Web Platform.

Rather than documenting only successful outcomes, it records the design changes, 
implementation challenges, and engineering decisions that improved the platform over time. 
The objective is to preserve institutional knowledge, guide future enhancements, and highlight the evolution of the platform.

## Engineering Principles Reinforced

Throughout development, several recurring engineering principles emerged:

- Automate repetitive tasks.
- Prefer repeatable processes over manual operations.
- Design for failure and recovery.
- Validate infrastructure after deployment.
- Reduce operational complexity through standardization.
- Keep configuration separate from implementation.
- Document architectural decisions and operational procedures.

## Lesson 1 — Infrastructure Dependencies Matter

### Initial Assumption

AWS resources could be created independently as long as the required configuration values were available.

### Reality

Many AWS services depend on other resources already existing before deployment.

Examples discovered during implementation:

```text
VPC
 └── Subnets

Subnets
 └── NAT Gateways

Security Groups
 └── Launch Templates

Launch Templates
 └── Auto Scaling Groups

DB Subnet Groups
 └── Aurora Clusters
```

Attempting to deploy resources out of order frequently resulted in failures.

Examples included:

* Missing VPC dependencies
* Missing subnet dependencies
* Missing security groups
* Missing database subnet groups

### Outcome

Deployment automation was redesigned around dependency ordering.

This resulted in:

* Predictable deployments
* Easier troubleshooting
* Improved reliability

---

## Lesson 2 — Configuration Centralization Improves Maintainability

### Initial Approach

Resource names, CIDRs, and deployment settings were defined directly inside deployment scripts.

### Problems

Changes required modifications across multiple files.

Examples:

* VPC names
* Subnet names
* Route table names
* Aurora identifiers

Configuration drift became increasingly difficult to manage.

### Solution

A centralized configuration model was implemented using:

```text
config/environment.conf
```

Benefits:

* Single source of truth
* Easier environment customization
* Reduced duplication
* Improved maintainability

---

## Lesson 3 — Strict Bash Settings Prevent Hidden Failures

### Discovery

Several deployment failures were traced to:

* Undefined variables
* Failed commands
* Silent pipeline errors

Examples encountered:

```text
unbound variable errors
missing configuration values
failed AWS CLI commands
```

### Solution

All scripts adopted:

```bash
set -euo pipefail
```

Benefits:

* Immediate failure detection
* Improved script reliability
* Faster troubleshooting

This became a standard pattern across the entire project.

---

## Lesson 4 — Resource Discovery Is Better Than Hardcoded IDs

### Initial Approach

Early automation relied on manually retrieving resource identifiers.

Examples:

```text
VPC IDs
Subnet IDs
Security Group IDs
```

### Problems

Resource IDs change between deployments.

Hardcoded values reduce portability and increase maintenance effort.

### Solution

Helper functions were created to dynamically discover resources by name and tags.

Examples:

```bash
find_vpc_by_name
find_subnet_by_name
find_security_group_by_name
```

Benefits:

* Environment portability
* Reduced manual effort
* More resilient automation

---

## Lesson 5 — Idempotency Is Essential

### Discovery

Real deployments are rarely executed only once.

Scripts were frequently rerun during:

* Development
* Troubleshooting
* Validation
* Recovery testing

Without idempotency, rerunning scripts caused:

* Duplicate resources
* Deployment failures
* Operational confusion

### Solution

Every deployment script was redesigned to:

```text
Check first
Create only if missing
Reuse if existing
```

Benefits:

* Safe redeployment
* Faster recovery
* Simplified troubleshooting

---

## Lesson 6 — AWS Deletion Dependencies Are Often More Complex Than Creation Dependencies

### Discovery

Destroy automation exposed a class of problems not encountered during deployment.

Examples included:

```text
Target Group in use by Listener
Listener attached to Load Balancer
Load Balancer attached to Security Groups
```

AWS prevented deletion until dependencies were removed.

Example error:

```text
ResourceInUse:
Target group is currently in use by a listener or rule
```

### Solution

Destroy automation was redesigned using reverse dependency ordering.

Example:

```text
Delete Listener
       ↓
Delete Load Balancer
       ↓
Delete Target Group
```

This significantly improved cleanup reliability.

---

## Lesson 7 — Production Networking Is More Complex Than It Appears

### Discovery

Networking represented the largest portion of the project.

Topics that required significant refinement:

* Route tables
* NAT Gateways
* Elastic IPs
* Security groups
* Subnet placement
* Multi-AZ design

Several troubleshooting sessions involved:

```text
Missing routes
Incorrect associations
Missing NAT connectivity
Subnet discovery issues
```

### Outcome

The final design adopted:

* Dedicated public subnets
* Dedicated application subnets
* Dedicated database subnets
* Multi-AZ NAT Gateway architecture

This more closely resembles enterprise AWS networking patterns.

---

## Lesson 8 — Validation Is Just As Important As Deployment

### Initial Assumption

A successful deployment script implied a successful environment.

### Reality

Resources can exist while still being unusable.

Examples:

* Unhealthy targets
* Failed user-data execution
* Incorrect route associations
* Failed database initialization

### Solution

Dedicated validation automation was implemented.

Examples verified:

* Resource existence
* Service health
* Auto Scaling status
* Target group health
* Aurora availability

This ultimately became:

```text
verify.sh
```

---

## Lesson 9 — Launch Templates Require Lifecycle Management

### Discovery

Updating user-data scripts does not automatically update running instances.

AWS stores user-data inside Launch Template versions.

Changing:

```text
user-data/app-server.sh
```

does not update existing EC2 instances.

### Solution

Launch Template versioning was introduced.

Workflow:

```text
Update user-data
      ↓
Create Launch Template Version
      ↓
Instance Refresh
      ↓
Deploy Updated Instances
```

This mirrors how production Auto Scaling environments are maintained.

---

## Lesson 10 — Documentation Is Part Of The Platform

### Discovery

As infrastructure complexity increased, documentation became increasingly important.

Without documentation:

* Architecture decisions became unclear
* Troubleshooting became slower
* Operational knowledge remained undocumented

### Outcome

Documentation evolved into multiple domains:

```text
Architecture
Deployment
Governance
Operations
```

The platform now includes:

* Architecture documentation
* Network design documentation
* Security documentation
* Monitoring strategy
* Operational runbooks
* Disaster recovery planning
* Incident response scenarios

---

## Lesson 11 — Building Infrastructure Teaches More Than Studying Infrastructure

Certifications provide valuable foundational knowledge.

However, the largest learning gains came from:

* Deploying resources
* Breaking deployments
* Fixing failures
* Designing automation
* Troubleshooting AWS behavior

Many concepts became significantly clearer only after implementation, including:

* Security group relationships
* NAT Gateway routing
* Auto Scaling behavior
* Launch Template lifecycle management
* Aurora deployment dependencies

The practical experience gained through implementation was substantially deeper than theoretical study alone.

---

## Future Improvements

Areas identified for future enhancement include:

* Terraform implementation
* CI/CD deployment pipelines
* GitHub Actions integration
* AWS Secrets Manager integration
* CloudWatch dashboards
* AWS Config compliance checks
* AWS WAF integration
* CloudTrail auditing
* Infrastructure testing pipelines

---

## Design Goals

This retrospective was intentionally created to document:

* Engineering lessons learned
* Architectural evolution
* Operational improvements
* Infrastructure design decisions
* Practical AWS implementation experience
* Continuous improvement practices

---

## Summary

Building the AWS Web Platform reinforced that successful cloud engineering extends beyond provisioning resources.

Key themes emerged throughout the project:

* Dependency management
* Automation design
* Validation
* Operational readiness
* Security
* Documentation
* Recoverability

The final platform reflects not only a deployed AWS environment, but also the engineering 
practices required to operate and maintain cloud infrastructure in a production-oriented setting.