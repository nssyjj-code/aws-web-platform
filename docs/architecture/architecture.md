# AWS Web Platform Architecture

## Executive Summary

The AWS Web Platform is a production-style three-tier web application environment deployed entirely within AWS.

The platform demonstrates enterprise cloud architecture principles including:

* High availability
* Secure network segmentation
* Horizontal scalability
* Infrastructure automation
* Operational monitoring
* Disaster recovery planning

Infrastructure is provisioned through AWS CLI automation and follows repeatable deployment and validation processes.

---

## Architecture Diagram

![Architecture Diagram](./diagrams/architecture.svg)

---

## Design Principles

The architecture was designed around the following principles:

### High Availability

Critical infrastructure components are deployed across multiple Availability Zones to reduce the impact of individual infrastructure failures.

### Security by Default

Application and database resources are isolated within private subnets and protected through layered security controls.

### Infrastructure Automation

All infrastructure resources are provisioned through version-controlled deployment scripts.

### Operational Simplicity

The platform uses managed AWS services where appropriate to reduce operational overhead.

### Cost Awareness

The environment balances production-style architecture patterns with practical cost management considerations.

---

## High-Level Architecture

The platform follows a traditional three-tier architecture.

```text
Presentation Tier
        │
        ▼
Application Tier
        │
        ▼
Data Tier
```

### Service Mapping

| Architecture Tier | AWS Service               |
| ----------------- | ------------------------- |
| Presentation      | Application Load Balancer |
| Application       | EC2 Auto Scaling Group    |
| Compute           | Amazon EC2                |
| Database          | Amazon Aurora MySQL       |
| Monitoring        | Amazon CloudWatch         |
| Notifications     | Amazon SNS                |
| Access Management | IAM & Systems Manager     |

---

## Physical Architecture

### Region

```text
us-east-1
```

### VPC

```text
10.0.0.0/16
```

### Availability Zones

```text
us-east-1a
us-east-1b
```

### Subnet Design

| Tier                | Subnet Type             | Availability |
| ------------------- | ----------------------- | ------------ |
| Public              | ALB and NAT Gateways    | Multi-AZ     |
| Private Application | EC2 Application Servers | Multi-AZ     |
| Private Database    | Aurora MySQL            | Multi-AZ     |

### Network Components

The platform includes:

* Internet Gateway
* Public Route Table
* Private Application Route Tables
* Private Database Route Table
* NAT Gateway AZ1
* NAT Gateway AZ2

Detailed network documentation:

```text
docs/architecture/network-design.md
```

---

## Component Architecture

```text
Internet
    │
    ▼
Application Load Balancer
    │
    ▼
Target Group
    │
    ▼
Auto Scaling Group
    │
    ▼
EC2 Application Instances
    │
    ▼
Aurora MySQL Cluster
```

---

## Core Components

### Application Load Balancer

The Application Load Balancer serves as the public entry point for all user traffic.

Responsibilities:

* Request routing
* Health monitoring
* Traffic distribution
* High availability

Benefits:

* Eliminates single-instance dependency
* Supports horizontal scaling
* Integrates with Auto Scaling Groups

---

### Auto Scaling Group

The Auto Scaling Group manages application server lifecycle operations.

Configuration:

```text
Minimum Capacity: 2
Desired Capacity: 2
Maximum Capacity: 4
```

Responsibilities:

* Instance replacement
* Capacity management
* Multi-AZ distribution
* Health-based recovery

---

### EC2 Application Tier

Application servers execute application workloads and business logic.

Characteristics:

* Private deployment
* No public IP addresses
* Managed by Auto Scaling
* Receives traffic only from the ALB

---

### Aurora MySQL Cluster

Aurora MySQL provides the platform's relational database layer.

Responsibilities:

* Persistent storage
* Backup management
* High availability support
* Managed database operations

Characteristics:

* Private deployment
* Restricted network access
* Storage encryption enabled

---

## Traffic Flow

### Request Path

```text
User
  │
  ▼
Application Load Balancer
  │
  ▼
EC2 Application Instance
  │
  ▼
Aurora MySQL Cluster
```

### Response Path

```text
Aurora MySQL Cluster
  │
  ▼
Application Instance
  │
  ▼
Application Load Balancer
  │
  ▼
User
```

---

## Security Architecture

The platform implements layered security controls.

### Network Security

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

### Security Controls

* Private application subnets
* Private database subnets
* Security group isolation
* IAM role-based access
* No public database access
* Systems Manager administration
* No inbound SSH requirements

Detailed security documentation:

```text
docs/governance/security.md
```

---

## Monitoring Architecture

Operational visibility is provided through native AWS monitoring services.

### Monitoring Components

* CloudWatch Dashboards
* CloudWatch Alarms
* SNS Notifications

### Monitored Resources

* Application Load Balancer
* Auto Scaling Group
* EC2 Instances
* Aurora Cluster
* Aurora Instances

Detailed monitoring documentation:

```text
docs/operations/monitoring-strategy.md
```

---

## Availability Strategy

The platform minimizes single points of failure through:

* Multi-AZ deployment
* Load-balanced application traffic
* Auto Scaling recovery
* Managed database services
* Redundant NAT Gateways

Benefits:

* Fault isolation
* Service continuity
* Automated recovery

---

## Operational Lifecycle

The platform supports a complete infrastructure lifecycle.

Capabilities include:

* Automated deployment
* Infrastructure validation
* Monitoring and alerting
* Incident response procedures
* Automated environment destruction

Supporting documentation:

```text
docs/deployment/deployment-guide.md
docs/operations/operational-runbook.md
docs/operations/incident-scenarios.md
```

---

## Related Architecture Decisions

Key design decisions are documented in:

```text
docs/architecture/architecture-decisions.md
```

Topics include:

* Three-tier architecture
* Multi-AZ deployment
* Aurora adoption
* Auto Scaling design
* Monitoring strategy
* Systems Manager access model

---

## Summary

The AWS Web Platform demonstrates a production-style AWS architecture that emphasizes:

* Availability
* Security
* Scalability
* Automation
* Monitoring
* Operational maintainability

The design intentionally mirrors common enterprise AWS deployment patterns while remaining practical for learning, demonstration, and portfolio purposes.