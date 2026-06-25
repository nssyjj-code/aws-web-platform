# Network Design

## Overview

This document describes the networking architecture used by the AWS Web Platform.

The environment is deployed within a dedicated Amazon Virtual Private Cloud (VPC) and follows a multi-tier network design that separates public-facing resources, application services, and database services.

The design emphasizes:

* Security
* High availability
* Controlled internet exposure
* Network segmentation
* Operational simplicity
* Production-style AWS networking patterns

---

## Network Design Principles

The network architecture was designed around the following principles.

### Least Privilege Networking

Only required communication paths are permitted between tiers.

### Defense in Depth

Security controls exist at multiple layers including subnet placement, route tables, security groups, and IAM controls.

### High Availability

Network resources are distributed across multiple Availability Zones.

### Separation of Duties

Public, application, and database workloads operate within dedicated network segments.

### Controlled Internet Access

Internet connectivity is explicitly managed through Internet Gateways and NAT Gateways.

---

## Network Architecture

The platform is deployed across two Availability Zones within a single AWS Region.

```text
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Subnets
    │
    ▼
Application Load Balancer
    │
    ▼
Private Application Subnets
    │
    ▼
Private Database Subnets
```

---

## VPC Design

### Region

```text
us-east-1
```

### VPC CIDR

```text
10.0.0.0/16
```

### Availability Zones

```text
us-east-1a
us-east-1b
```

### VPC Capacity

The selected CIDR range provides:

```text
65,536 IPv4 addresses
```

Benefits:

* Supports future growth
* Simplifies subnet allocation
* Common enterprise design pattern
* Reduces risk of CIDR exhaustion

---

## Availability Zone Design

Resources are distributed across:

```text
us-east-1a
us-east-1b
```

Benefits:

* Fault isolation
* Increased resiliency
* Reduced single points of failure
* Support for highly available services

If a single Availability Zone becomes unavailable, infrastructure can continue operating in the remaining zone.

---

## Subnet Design

The platform uses six dedicated subnets.

### Public Subnets

| Subnet            | CIDR        | Availability Zone | Purpose             |
| ----------------- | ----------- | ----------------- | ------------------- |
| Public Subnet AZ1 | 10.0.1.0/24 | us-east-1a        | ALB and NAT Gateway |
| Public Subnet AZ2 | 10.0.2.0/24 | us-east-1b        | ALB and NAT Gateway |

Responsibilities:

* Internet-facing resources
* Load balancer placement
* NAT Gateway placement

---

### Private Application Subnets

| Subnet          | CIDR         | Availability Zone | Purpose                 |
| --------------- | ------------ | ----------------- | ----------------------- |
| Private App AZ1 | 10.0.11.0/24 | us-east-1a        | EC2 Application Servers |
| Private App AZ2 | 10.0.12.0/24 | us-east-1b        | EC2 Application Servers |

Responsibilities:

* Application processing
* Auto Scaling Group placement
* Internal service communication

Characteristics:

* No public IP addresses
* No direct inbound internet access

---

### Private Database Subnets

| Subnet         | CIDR         | Availability Zone | Purpose      |
| -------------- | ------------ | ----------------- | ------------ |
| Private DB AZ1 | 10.0.21.0/24 | us-east-1a        | Aurora MySQL |
| Private DB AZ2 | 10.0.22.0/24 | us-east-1b        | Aurora MySQL |

Responsibilities:

* Database services
* Data persistence
* Private network communication

Characteristics:

* No internet access
* Application-tier access only

---

## Route Table Design

### Route Table Summary

| Route Table                  | Associated Resources   |
| ---------------------------- | ---------------------- |
| Public Route Table           | Public Subnets         |
| Private App Route Table AZ1  | Private App Subnet AZ1 |
| Private App Route Table AZ2  | Private App Subnet AZ2 |
| Private Database Route Table | Database Subnets       |

---

### Public Route Table

Default route:

```text
0.0.0.0/0 → Internet Gateway
```

Purpose:

* Public internet access
* ALB connectivity
* NAT Gateway connectivity

---

### Private Application Route Tables

Default route:

```text
0.0.0.0/0 → NAT Gateway
```

Purpose:

* Package updates
* External API communication
* AWS service access

Inbound internet traffic is not permitted.

---

### Database Route Table

Database resources remain isolated.

Characteristics:

* No direct internet access
* Application-tier communication only
* Restricted routing model

---

## Internet Connectivity Design

### Internet Gateway

The VPC contains a single Internet Gateway.

Responsibilities:

* Internet access for public resources
* ALB internet connectivity
* NAT Gateway internet connectivity

Traffic flow:

```text
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Subnets
```

---

### NAT Gateway Design

Each Availability Zone contains a dedicated NAT Gateway.

Architecture:

```text
Private App Subnet AZ1
          │
          ▼
     NAT Gateway AZ1

Private App Subnet AZ2
          │
          ▼
     NAT Gateway AZ2
```

Benefits:

* Outbound internet access
* No inbound exposure
* Improved fault isolation

Tradeoff:

* Higher monthly operating cost

---

## Security Boundaries

The network follows a layered security model.

```text
Internet
    │
    ▼
ALB Security Group
    │
    ▼
Application Security Group
    │
    ▼
Database Security Group
```

Allowed communication:

| Source           | Destination      | Port    |
| ---------------- | ---------------- | ------- |
| Internet         | ALB              | 80, 443 |
| ALB              | Application Tier | 80      |
| Application Tier | Aurora           | 3306    |

All other traffic is denied by default.

---

## Traffic Flow

### Inbound User Traffic

```text
Internet
    │
    ▼
Application Load Balancer
    │
    ▼
Application Instance
```

---

### Application to Database Traffic

```text
Application Instance
        │
        ▼
Aurora MySQL
```

---

### Outbound Application Traffic

```text
EC2 Instance
     │
     ▼
NAT Gateway
     │
     ▼
Internet
```

---

## Operational Considerations

### VPC Flow Logs

VPC Flow Logs are recommended for:

* Traffic visibility
* Troubleshooting
* Security investigations
* Compliance reporting

Future implementation may forward logs to CloudWatch Logs or Amazon S3.

---

### VPC Endpoints

Future enhancements may include:

* S3 Gateway Endpoints
* Systems Manager Interface Endpoints
* CloudWatch Interface Endpoints

Benefits:

* Reduced NAT Gateway usage
* Improved security
* Lower data transfer costs

---

## Failure Scenarios

### Availability Zone Failure

Impact:

* Loss of one subnet set
* Remaining AZ continues serving traffic

Mitigation:

* Multi-AZ deployment
* Auto Scaling Group distribution
* Aurora resilience features

---

### NAT Gateway Failure

Impact:

* Loss of outbound connectivity for affected subnet

Mitigation:

* Dedicated NAT Gateway per Availability Zone

---

### Internet Gateway Failure

Impact:

* Public connectivity loss

Mitigation:

* AWS managed service architecture

---

## Cost Considerations

The largest networking cost drivers are:

* NAT Gateways
* Data transfer
* Load Balancer usage

The design intentionally prioritizes availability and security over minimum cost.

Potential future optimizations:

* VPC Endpoints
* Traffic reduction strategies
* Cost-aware routing patterns

---

## Related Architecture Decisions

Relevant Architecture Decision Records:

```text
ADR-002 Multi-AZ Networking
ADR-003 Private Application Subnets
ADR-007 NAT Gateway Design
ADR-008 Security Group Referencing
```

Reference:

```text
docs/architecture/architecture-decisions.md
```

---

## Summary

The AWS Web Platform network architecture separates public, application, and database resources into dedicated subnet tiers distributed across multiple Availability Zones.

The design prioritizes:

* Security
* Availability
* Network segmentation
* Controlled internet access
* Operational maintainability

The resulting architecture closely mirrors networking patterns commonly used in production AWS environments while remaining practical for a portfolio and learning environment.