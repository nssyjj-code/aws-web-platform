# Security Design

## Overview

This document describes the security architecture, controls,
and design principles implemented within the AWS Web Platform.

The platform follows a defense-in-depth approach that applies
security controls across multiple layers of the environment including:

* Network security
* Identity and access management
* Administrative access
* Database protection
* Credential management
* Monitoring and detection
* Encryption
* Operational governance

Security decisions are based on AWS security best practices,
the AWS Shared Responsibility Model, and the principle of least privilege.

---

## Security Objectives

The platform was designed to achieve the following security objectives:

* Minimize public attack surface
* Enforce least-privilege access
* Protect sensitive resources
* Reduce credential exposure
* Secure administrative access
* Support operational auditing
* Enable future security enhancements

---

## Security Architecture

The environment uses layered security controls.

Traffic flow:

```text
Internet
    │
    ▼
Application Load Balancer
    │
    ▼
Private Application Tier
    │
    ▼
Private Database Tier
```

Each layer only accepts explicitly authorized traffic.

No component is granted broader access than required.

---

## Defense-in-Depth Strategy

Security is implemented at multiple layers.

```text
User
 │
 ▼
Application Load Balancer
 │
 ▼
Security Groups
 │
 ▼
Private Subnets
 │
 ▼
IAM Controls
 │
 ▼
Database Controls
```

Security does not rely on any single control.

Multiple overlapping protections reduce overall risk exposure.

---

## AWS Shared Responsibility Model

The platform follows the AWS Shared Responsibility Model.

### AWS Responsibilities

AWS secures:

* Physical infrastructure
* Data centers
* Networking hardware
* Hypervisor layer
* Managed service infrastructure

### Customer Responsibilities

This project secures:

* IAM configuration
* Security groups
* Application configuration
* Database configuration
* Secrets management
* Monitoring configuration
* Administrative access controls

---

## Network Security Design

### Public Tier

Public resources include:

* Application Load Balancer
* NAT Gateways

The Application Load Balancer serves as the only inbound application entry point.

Allowed inbound traffic:

```text
Internet
     │
     ▼
ALB Security Group

TCP 80
TCP 443 (future enhancement)
```

No EC2 instances are directly reachable from the internet.

---

### Application Tier Security

Application instances are deployed within private application subnets.

Security controls:

* No public IP addresses
* No inbound internet access
* Security group restrictions
* Systems Manager administration

Allowed communication:

```text
ALB Security Group
        │
        ▼
Application Security Group

TCP 80
```

Benefits:

* Reduced attack surface
* Controlled traffic paths
* Strong network segmentation

---

### Database Tier Security

Aurora MySQL is deployed within dedicated private database subnets.

Security controls:

* No public accessibility
* No internet routing
* Security group restrictions
* Private subnet placement

Allowed communication:

```text
Application Security Group
          │
          ▼
Database Security Group

TCP 3306
```

Blocked communication:

* Internet access
* Direct user access
* Public database endpoints

---

## Security Group Strategy

Security groups implement least-privilege network access.

---

### Load Balancer Security Group

#### Inbound

| Source   | Protocol | Port         |
| -------- | -------- | ------------ |
| Internet | TCP      | 80           |
| Internet | TCP      | 443 (future) |

#### Outbound

| Destination      | Purpose         |
| ---------------- | --------------- |
| Application Tier | Forward traffic |

---

### Application Security Group

#### Inbound

| Source             | Protocol | Port |
| ------------------ | -------- | ---- |
| ALB Security Group | TCP      | 80   |

#### Outbound

| Destination     | Purpose            |
| --------------- | ------------------ |
| Aurora Database | Database access    |
| NAT Gateway     | Software updates   |
| AWS Services    | Operational access |

---

### Database Security Group

#### Inbound

| Source                     | Protocol | Port |
| -------------------------- | -------- | ---- |
| Application Security Group | TCP      | 3306 |

Security group references are used instead of broad CIDR ranges wherever possible.

---

## Identity and Access Management

### EC2 IAM Role Design

Application instances receive AWS permissions through IAM roles.

Architecture:

```text
EC2 Instance
      │
      ▼
Instance Profile
      │
      ▼
IAM Role
      │
      ▼
AWS Services
```

Benefits:

* No embedded credentials
* Automatic credential rotation
* Reduced credential exposure
* AWS best-practice implementation

---

### Least Privilege Philosophy

Permissions should only grant access required to perform assigned responsibilities.

Benefits:

* Reduced blast radius
* Improved auditability
* Lower risk from compromised resources

---

## Administrative Access

Traditional SSH administration is intentionally avoided.

Not implemented:

```text
Internet
    │
    ▼
SSH Port 22
    │
    ▼
EC2 Instance
```

---

### Systems Manager Access Model

Preferred administrative path:

```text
Administrator
       │
       ▼
IAM Authentication
       │
       ▼
AWS Systems Manager
       │
       ▼
Private EC2 Instance
```

Benefits:

* No SSH keys
* No inbound ports
* IAM-based access control
* Session auditing support
* Reduced attack surface

---

## Credential Management

The repository intentionally excludes all secrets.

Not stored:

```text
AWS Access Keys
Database Passwords
Private Keys
Session Tokens
Application Secrets
```

---

### Database Credentials

Development deployments use environment variables.

Example:

```bash
export DB_MASTER_USERNAME="adminuser"
export DB_MASTER_PASSWORD="strong-password"
```

These values are never committed to source control.

---

### Production Recommendation

Production environments should use:

```text
AWS Secrets Manager
```

Benefits:

* Centralized secrets management
* Automatic rotation
* Audit visibility
* Reduced credential exposure

---

## Encryption Strategy

### Data in Transit

Current implementation:

* Private VPC networking
* AWS-managed transport security

Future enhancement:

```text
User
 │
HTTPS
 │
▼
Application Load Balancer
 │
▼
Application Tier
```

Recommended implementation:

* AWS Certificate Manager
* TLS certificates
* HTTPS listener
* HTTP to HTTPS redirection

---

### Data at Rest

Recommended encryption targets:

* Aurora storage
* EBS volumes
* Database snapshots
* Backup storage
* Secrets

Recommended service:

```text
AWS Key Management Service (KMS)
```

Benefits:

* Centralized key management
* Access control integration
* Audit capabilities

---

## Security Monitoring

Security monitoring should provide visibility into infrastructure activity and configuration changes.

---

### AWS CloudTrail

Purpose:

* API auditing
* Administrative activity logging
* Security investigations

---

### Amazon CloudWatch

Purpose:

* Operational monitoring
* Alert generation
* Security metric visibility

---

### AWS Config

Purpose:

* Configuration compliance
* Drift detection
* Continuous assessment

---

### VPC Flow Logs

Future implementation:

Purpose:

* Network visibility
* Traffic analysis
* Security investigations

---

## Security Control Matrix

| Security Domain       | Control                                        |
| --------------------- | ---------------------------------------------- |
| Network Security      | Private subnet architecture                    |
| Access Control        | IAM roles                                      |
| Administrative Access | Systems Manager                                |
| Database Security     | Private Aurora deployment                      |
| Traffic Restriction   | Security groups                                |
| Secrets Protection    | Environment variables / future Secrets Manager |
| Monitoring            | CloudTrail, CloudWatch                         |
| Future Compliance     | AWS Config                                     |

---

## Incident Response Considerations

Security monitoring should support:

* Unauthorized access investigations
* IAM activity reviews
* Configuration change analysis
* Resource exposure validation
* Network traffic analysis

Additional guidance:

```text
docs/operations/incident-scenarios.md
docs/operations/operational-runbook.md
```

---

## Security Roadmap

Planned future enhancements:

* HTTPS enforcement
* AWS Certificate Manager integration
* AWS WAF
* AWS Secrets Manager
* CloudTrail deployment
* AWS Config compliance monitoring
* GuardDuty threat detection
* VPC Flow Logs
* Vulnerability scanning
* CI/CD security scanning
* Security Hub integration

---

## Related Architecture Decisions

Relevant ADRs include:

```text
ADR-003 Private Application Subnets
ADR-007: Use NAT Gateways
ADR-008 Security Group Referencing
ADR-012 Systems Manager Instead of SSH
```

Reference:

```text
docs/architecture/architecture-decisions.md
```

---

## Design Goals

The security architecture was intentionally designed to demonstrate:

* Defense in depth
* Least-privilege access
* Secure network segmentation
* IAM role-based authentication
* AWS-native security services
* Production-style AWS security patterns

---

## Summary

The AWS Web Platform implements layered security controls across networking,
identity, administration, database protection, and operational monitoring.

The design emphasizes:

* Defense in depth
* Least privilege access
* Reduced attack surface
* Secure administration
* Future security extensibility

The resulting architecture closely aligns with common security patterns used in modern
AWS production environments while remaining practical for development and portfolio use.
