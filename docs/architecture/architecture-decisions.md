# Architecture Decision Records (ADR)

## Overview

This document records the major architecture decisions made for the AWS Web Platform.

The purpose of these Architecture Decision Records (ADRs) is to document not only what was built, but why specific AWS services, networking patterns, security controls, and operational practices were selected.

Each ADR contains:

* Status
* Context
* Decision
* Consequences
* Alternatives Considered

---

# ADR-001: Use a Three-Tier Architecture

## Status

Accepted

## Context

The project required a production-style web platform that separates public traffic handling, application compute, and database services.

## Decision

Use a three-tier architecture:

```text
Public Tier       → Application Load Balancer
Application Tier  → EC2 Instances in Auto Scaling Group
Database Tier     → Aurora MySQL
```

## Consequences

### Positive

* Clear separation of responsibilities
* Improved security boundaries
* Easier horizontal scaling
* Aligns with common enterprise cloud patterns

### Negative

* Increased deployment complexity
* Higher infrastructure costs than a single-instance design

## Alternatives Considered

| Alternative                             | Reason Not Selected                                                |
| --------------------------------------- | ------------------------------------------------------------------ |
| Single EC2 instance with local database | Too simple and not production-oriented                             |
| Serverless-only architecture            | Valid option, but not aligned with networking and operations goals |
| Public EC2 application instances        | Larger attack surface                                              |

---

# ADR-002: Use Multi-AZ Networking

## Status

Accepted

## Context

The platform should avoid dependence on a single Availability Zone.

## Decision

Deploy public, private application, and private database subnets across two Availability Zones.

## Consequences

### Positive

* Improved availability
* Better fault isolation
* Supports resilient infrastructure design

### Negative

* Increased NAT Gateway costs
* Additional networking complexity

## Alternatives Considered

| Alternative          | Reason Not Selected                                |
| -------------------- | -------------------------------------------------- |
| Single-AZ deployment | Single point of failure                            |
| Three-AZ deployment  | Increased cost and complexity beyond project scope |

---

# ADR-003: Place Application Instances in Private Subnets

## Status

Accepted

## Context

Application servers must serve public traffic while minimizing direct exposure.

## Decision

Deploy EC2 application instances into private subnets.

## Consequences

### Positive

* Reduced attack surface
* No public IPs required
* Supports least-privilege network design

### Negative

* Requires NAT Gateways for outbound internet access
* Slightly more complex troubleshooting

## Alternatives Considered

| Alternative               | Reason Not Selected                      |
| ------------------------- | ---------------------------------------- |
| Public EC2 instances      | Increased exposure                       |
| Bastion host architecture | Additional management overhead           |
| Fully isolated network    | Not suitable for public web applications |

---

# ADR-004: Use an Application Load Balancer

## Status

Accepted

## Context

The platform requires public web access and traffic distribution across multiple application instances.

## Decision

Use an internet-facing Application Load Balancer.

## Consequences

### Positive

* Native health checks
* Traffic distribution
* Auto Scaling integration
* High availability

### Negative

* Additional monthly cost
* Additional infrastructure component to manage

## Alternatives Considered

| Alternative                | Reason Not Selected                          |
| -------------------------- | -------------------------------------------- |
| Network Load Balancer      | Optimized for TCP/UDP workloads              |
| Elastic IP directly on EC2 | Not highly available                         |
| CloudFront only            | Does not replace load balancing requirements |

---

# ADR-005: Use Auto Scaling Groups

## Status

Accepted

## Context

Application instances should be replaceable and horizontally scalable.

## Decision

Deploy EC2 instances through an Auto Scaling Group using a Launch Template.

## Consequences

### Positive

* Self-healing infrastructure
* Automated instance replacement
* Consistent deployments
* Multi-AZ distribution

### Negative

* Additional operational complexity
* Requires monitoring and health checks

## Alternatives Considered

| Alternative                     | Reason Not Selected                   |
| ------------------------------- | ------------------------------------- |
| Manually launched EC2 instances | Not repeatable                        |
| ECS/Fargate                     | Outside project scope                 |
| Lambda                          | Not aligned with infrastructure goals |

---

# ADR-006: Use Aurora MySQL

## Status

Accepted

## Context

The platform requires a managed relational database service.

## Decision

Use Amazon Aurora MySQL.

## Consequences

### Positive

* Managed service
* High availability features
* Automated backups
* MySQL compatibility

### Negative

* Higher cost than standard MySQL deployments
* AWS-specific implementation

## Alternatives Considered

| Alternative  | Reason Not Selected                                                           |
| ------------ | ----------------------------------------------------------------------------- |
| MySQL on EC2 | Increased operational burden                                                  |
| RDS MySQL    | Valid option, but Aurora demonstrates more advanced managed database patterns |
| DynamoDB     | Does not meet relational database requirements                                |

---

# ADR-007: Use NAT Gateways

## Status

Accepted

## Context

Private application instances require outbound internet access.

## Decision

Deploy NAT Gateways in public subnets.

## Consequences

### Positive

* Private instances can access the internet securely
* No inbound internet exposure
* Managed AWS service

### Negative

* One of the largest recurring cost components
* Additional networking dependencies

## Alternatives Considered

| Alternative                | Reason Not Selected              |
| -------------------------- | -------------------------------- |
| Public IP addresses on EC2 | Increased exposure               |
| NAT Instance               | Requires management and patching |
| No internet access         | Too restrictive                  |

---

# ADR-008: Use Security Group Referencing

## Status

Accepted

## Context

Traffic between tiers should be tightly controlled.

## Decision

Use Security Group references rather than broad CIDR rules.

```text
Internet
    ↓
ALB Security Group
    ↓
Application Security Group
    ↓
Database Security Group
```

## Consequences

### Positive

* Least-privilege communication
* Easier maintenance
* Improved security posture

### Negative

* Requires dependency-aware deployments

## Alternatives Considered

| Alternative            | Reason Not Selected   |
| ---------------------- | --------------------- |
| Broad CIDR access      | Less secure           |
| Public database access | Not acceptable        |
| Static allowlists      | Difficult to maintain |

---

# ADR-009: Use AWS CLI Automation

## Status

Accepted

## Context

The project required repeatable infrastructure deployment while reinforcing AWS service-level knowledge.

## Decision

Deploy infrastructure using AWS CLI automation scripts.

## Consequences

### Positive

* Demonstrates AWS service knowledge
* Highlights resource dependencies
* Enables repeatable deployments

### Negative

* Manual dependency management
* No state management

## Alternatives Considered

| Alternative       | Reason Not Selected                                                                |
| ----------------- | ---------------------------------------------------------------------------------- |
| Terraform         | Excellent production tool, but abstracts some service-level implementation details |
| CloudFormation    | Strong AWS-native option, but not the focus of this project                        |
| Manual deployment | Not repeatable                                                                     |

## Future Evolution

If this platform were maintained long term, Terraform would likely become the preferred deployment method due to:

* State management
* Drift detection
* Collaboration support
* Reusability

---

# ADR-010: Use Automated Infrastructure Teardown

## Status

Accepted

## Context

Development environments can generate unnecessary cost when left running.

## Decision

Implement a dependency-aware destroy process.

## Consequences

### Positive

* Cost control
* Demonstrates lifecycle ownership
* Safe resource cleanup

### Negative

* Additional development effort

## Alternatives Considered

| Alternative             | Reason Not Selected       |
| ----------------------- | ------------------------- |
| Manual cleanup          | Error-prone               |
| Leave resources running | Unnecessary cost          |
| Delete VPC first        | Fails due to dependencies |

---

# ADR-011: Use CloudWatch for Monitoring

## Status

Accepted

## Context

The platform requires operational visibility into infrastructure health and application availability.

## Decision

Use Amazon CloudWatch dashboards and alarms.

## Consequences

### Positive

* Native AWS integration
* Infrastructure monitoring
* Alarm notifications
* Auto Scaling visibility

### Negative

* AWS-specific monitoring implementation

## Alternatives Considered

| Alternative            | Reason Not Selected             |
| ---------------------- | ------------------------------- |
| Datadog                | Additional licensing cost       |
| Prometheus and Grafana | Additional operational overhead |
| No monitoring          | Not acceptable                  |

---

# ADR-012: Use AWS Systems Manager Instead of SSH

## Status

Accepted

## Context

Administrative access to EC2 instances should minimize exposure and operational overhead.

## Decision

Use AWS Systems Manager Session Manager rather than direct SSH access.

## Consequences

### Positive

* No inbound SSH ports required
* Reduced attack surface
* Centralized auditing
* No SSH key management

### Negative

* Requires SSM permissions and agent availability

## Alternatives Considered

| Alternative       | Reason Not Selected                      |
| ----------------- | ---------------------------------------- |
| Public SSH access | Increased attack surface                 |
| Bastion host      | Additional infrastructure                |
| VPN access        | Unnecessary complexity for project scope |

---

# Summary

These architecture decisions balance:

* Security
* Availability
* Cost
* Operational complexity
* Educational value

The project intentionally favors production-style AWS design patterns while documenting tradeoffs, operational considerations, and future evolution paths.