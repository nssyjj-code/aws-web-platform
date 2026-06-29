# AWS Web Platform

[![Markdown Lint](https://github.com/nssyjj-code/aws-web-platform/actions/workflows/markdown-lint.yml/badge.svg)](https://github.com/nssyjj-code/aws-web-platform/actions/workflows/markdown-lint.yml)
[![ShellCheck](https://github.com/nssyjj-code/aws-web-platform/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/nssyjj-code/aws-web-platform/actions/workflows/shellcheck.yml)
[![Validate Shell Syntax](https://github.com/nssyjj-code/aws-web-platform/actions/workflows/validate-shell.yml/badge.svg)](https://github.com/nssyjj-code/aws-web-platform/actions/workflows/validate-shell.yml)

A production-style AWS infrastructure platform built with Bash
and the AWS CLI to demonstrate cloud engineering, automation,
networking, security, operational readiness, and infrastructure
lifecycle management.

The project provisions a highly available three-tier web application
environment across multiple Availability Zones using modular,
idempotent deployment automation and AWS managed services.

> This project was intentionally built using AWS CLI automation before
> transitioning to Terraform in order to develop a deeper understanding
> of AWS service dependencies, infrastructure provisioning workflows,
> and operational troubleshooting.

---

## Project Status

✅ Completed

The platform has been successfully deployed,
validated, monitored, and documented.

Current implementation includes:

• Multi-AZ networking
• Auto Scaling
• Aurora
• ALB
• Bash automation
• CloudWatch monitoring
• Operational documentation

## Project Goals

This project was designed to demonstrate production-style Cloud Engineering
practices using native AWS services and Bash automation.

Primary objectives include:

- Infrastructure automation
- High availability
- Security best practices
- Multi-tier networking
- Operational readiness
- Monitoring
- Infrastructure validation
- Repeatable deployments

---

## Architecture Overview

![AWS Production Web Platform Architecture](docs/architecture/diagrams/architecture.svg)

### High-Level Design

```text
Internet
    │
    ▼
Application Load Balancer
    │
    ▼
Auto Scaling Group
    │
    ▼
Private EC2 Application Instances
    │
    ▼
Aurora MySQL Cluster
```

### Key Architecture Characteristics

* Multi-AZ deployment across two Availability Zones
* Public, private application, and private database subnet tiers
* Internet-facing Application Load Balancer
* Auto Scaling application layer
* Private Aurora MySQL database
* NAT Gateway architecture for outbound internet access
* Layered security group design
* IAM role-based EC2 access
* Infrastructure lifecycle automation
* Environment validation and recovery workflows

---

## Technology Stack

### AWS Services

* Amazon VPC
* Amazon EC2
* EC2 Launch Templates
* EC2 Auto Scaling
* Elastic Load Balancing (ALB)
* Amazon Aurora MySQL
* IAM Roles and Instance Profiles
* NAT Gateways
* Internet Gateway
* CloudWatch
* Systems Manager (SSM)

### Languages & Tools

* Bash
* AWS CLI v2
* Git
* GitHub
* Draw.io
* ShellCheck

---

## Skills Demonstrated

This project demonstrates practical experience with:

### Cloud Infrastructure

* Multi-tier AWS architecture
* Multi-AZ deployments
* High availability design
* Infrastructure lifecycle management

### Networking

* VPC design
* CIDR planning
* Public and private subnet architecture
* Route tables
* Internet Gateways
* NAT Gateways

### Security

* Security group segmentation
* Least privilege design
* IAM roles and instance profiles
* Private application and database tiers
* Secrets handling practices

### Automation

* Modular Bash automation
* Idempotent deployment design
* Dependency-aware provisioning
* Environment validation
* Automated teardown

### Operations

* Monitoring strategy
* Incident response procedures
* Disaster recovery planning
* Operational runbooks
* Troubleshooting workflows

---

## Features

### Infrastructure

* Multi-AZ VPC architecture
* Public and private subnet segmentation
* Highly available NAT Gateway design
* Layered security group model
* IAM-based EC2 access

### Compute

* Launch Templates
* Auto Scaling Group
* Automated instance replacement
* EC2 bootstrap automation via user-data

### Load Balancing

* Application Load Balancer
* Target Groups
* Health checks
* Cross-AZ traffic distribution

### Database

* Aurora MySQL Cluster
* Private database deployment
* Dedicated DB subnet group
* Security group isolation

### Automation

* Configuration-driven deployments
* Shared helper libraries
* Modular deployment scripts
* Idempotent resource creation
* Automated validation
* Automated environment cleanup

---

## Quick Start

### Prerequisites

* AWS Account
* AWS CLI v2
* Git
* Bash

Configure AWS credentials:

```bash
aws configure
```

Verify authentication:

```bash
aws sts get-caller-identity
```

> Warning: This project provisions billable AWS resources including NAT Gateways, Load Balancers, EC2 instances, and Aurora. Destroy resources after testing.

---

### Database Credentials

Aurora credentials are intentionally excluded from source control.

Set required environment variables:

```bash
export DB_MASTER_USERNAME="adminuser"
export DB_MASTER_PASSWORD="ReplaceWithAStrongPassword"
```

---

### Deploy

Deploy the entire platform:

```bash
./deploy.sh
```

---

### Verify

Validate deployed resources:

```bash
./verify.sh
```

---

### Destroy

Remove all deployed resources:

```bash
./destroy.sh
```

---

## Validation Results

The platform has been successfully validated using the
complete deployment lifecycle.

### Deployment Workflow

```text
deploy.sh

↓

verify.sh

↓

destroy.sh
```

### Validation Summary

Successful validation confirms:

- Multi-AZ VPC deployment
- Public/private subnet segmentation
- Internet-facing ALB
- Auto Scaling Group
- Healthy Target Group
- Launch Template
- Aurora MySQL
- Security Groups
- NAT Gateway routing
- Private EC2 instances
- Automated teardown

---

## Repository Structure

```text
aws-web-platform/

├── config/
├── docs/
│   ├── architecture/
│   ├── deployment/
│   ├── governance/
│   ├── operations/
│   └── project/
│
├── monitoring/
├── policies/
├── scripts/
├── user-data/
│
├── deploy.sh
├── verify.sh
├── destroy.sh
└── README.md
```

---

## Documentation

### Architecture

* Architecture Overview
* Architecture Decisions
* Network Design

Location:

```text
docs/architecture/
```

### Deployment

* Deployment Guide
* Automation Design
* AWS Authentication
* Testing Strategy

Location:

```text
docs/deployment/
```

### Operations

* Monitoring Strategy
* Operational Runbook
* Incident Scenarios
* Disaster Recovery Plan
* Lessons Learned

Location:

```text
docs/operations/
```

### Governance

* Security Design
* Cost Optimization

Location:

```text
docs/governance/
```

---

## Monitoring

The platform includes CloudWatch monitoring automation.

Current implementation:

* CloudWatch dashboards
* ALB health monitoring
* Auto Scaling monitoring
* Aurora monitoring
* CloudWatch alarms

Examples include:

* Unhealthy targets
* HTTP 5XX errors
* Elevated latency
* Capacity issues
* Database health events

---

## Security Highlights

* No AWS credentials stored in source control
* EC2 IAM roles instead of access keys
* Private application tier
* Private database tier
* Layered security group model
* Least privilege access principles
* Systems Manager support for administrative access

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

## Lessons Learned

A dedicated engineering retrospective documents key lessons learned while building and operating the platform, including:

* Dependency management
* Infrastructure automation
* AWS networking
* Launch Template lifecycle management
* Idempotent deployments
* Operational validation

See:

```text
docs/operations/lessons-learned.md
```

---

## Future Roadmap

Planned enhancements include:

* Terraform implementation
* GitHub Actions CI/CD
* AWS Secrets Manager integration
* CloudWatch dashboard automation
* AWS WAF
* CloudTrail auditing
* AWS Config compliance rules
* Infrastructure testing pipelines
* OpenID Connect (OIDC) authentication

---

## Why This Project Exists

Many AWS portfolio projects focus only on resource creation.

This project was designed to go further by emphasizing:

* Architecture design
* Security
* Automation
* Operations
* Monitoring
* Incident response
* Disaster recovery
* Documentation

The goal is to demonstrate the responsibilities commonly performed by Cloud Engineers and Cloud Operations Engineers in production AWS environments.

---

## License

This project is licensed under the MIT License.
