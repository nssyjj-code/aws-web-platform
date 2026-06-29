# Cost Optimization

## Overview

This document describes the cost considerations, optimization strategies, 
and architectural tradeoffs associated with the AWS Web Platform.

The platform was intentionally designed to demonstrate production-style AWS architecture 
patterns while maintaining awareness of infrastructure cost management.

The goal is not simply to minimize spending, but to understand the engineering tradeoffs between:

* Cost
* Availability
* Security
* Performance
* Operational complexity

This project aligns with concepts from the AWS Well-Architected Framework Cost Optimization Pillar.

---

## Cost Optimization Objectives

The platform was designed with the following cost optimization objectives:

* Understand primary AWS cost drivers
* Avoid unnecessary resource consumption
* Right-size infrastructure components
* Balance cost with availability requirements
* Support environment lifecycle management
* Demonstrate production-oriented architecture decisions
* Encourage cost visibility and accountability

---

## AWS Well-Architected Alignment

This project incorporates several principles from the AWS Well-Architected Framework Cost Optimization Pillar.

Implemented practices include:

* Right-sized EC2 instance selection
* Controlled Auto Scaling limits
* Resource lifecycle automation
* Automated environment teardown
* Centralized configuration management
* Resource tagging standards
* Cost-aware architecture decisions

Cost optimization is treated as a continuous operational responsibility rather than a one-time design exercise.

---

## Cost Awareness

This platform provisions multiple managed AWS services.

Expected operating costs will vary depending on:

* AWS Region
* EC2 instance sizing
* Aurora instance sizing
* Storage utilization
* Network traffic
* Environment runtime duration
* Future architecture modifications

Users should always review current AWS pricing before deployment.

The largest cost contributors are typically:

* NAT Gateways
* Aurora resources
* Application Load Balancers
* EC2 compute resources

---

## Cost Management Recommendation

This environment is intended primarily for:

* Learning
* Portfolio development
* Architecture demonstrations
* Infrastructure automation practice

The environment should be destroyed when not actively being used.

Cleanup command:

```bash
./destroy.sh
```

Automated teardown helps reduce unnecessary AWS charges and encourages responsible cloud resource management.

---

## Cost Design Philosophy

This project intentionally prioritizes learning production architecture 
patterns over building the lowest-cost AWS environment.

Several architectural decisions increase cost but more accurately reflect real-world enterprise deployments.

Examples include:

* Multi-AZ networking
* Dedicated NAT Gateways
* Aurora MySQL
* Application Load Balancer
* Auto Scaling architecture
* Private application infrastructure

The objective is to demonstrate production design principles rather than optimize exclusively for minimum cost.

---

## Portfolio Design vs Cost Optimization

This project intentionally does not represent the least expensive AWS implementation.

Many architectural choices were selected to demonstrate enterprise cloud design patterns.

| Component      | Lower Cost Option   | Implemented Design        |
| -------------- | ------------------- | ------------------------- |
| NAT Gateway    | Single NAT Gateway  | Multi-AZ NAT Gateways     |
| Database       | RDS MySQL           | Aurora MySQL              |
| Compute        | Single EC2 Instance | Auto Scaling Group        |
| Networking     | Flat Network        | Segmented Three-Tier VPC  |
| Administration | SSH Access          | AWS Systems Manager       |
| Load Balancing | Single Instance     | Application Load Balancer |

The selected architecture increases cost while improving:

* Availability
* Fault tolerance
* Security
* Operational maturity
* Demonstration of AWS best practices

---

## Primary Cost Drivers

| AWS Service               | Purpose                        | Cost Consideration                            |
| ------------------------- | ------------------------------ | --------------------------------------------- |
| Application Load Balancer | Traffic distribution           | Hourly usage and Load Balancer Capacity Units |
| EC2 Instances             | Application compute            | Runtime duration, sizing, storage             |
| Auto Scaling Group        | Compute availability           | Number of running instances                   |
| Aurora MySQL              | Database services              | Instance runtime, storage, backups, I/O       |
| NAT Gateway               | Private subnet internet access | Hourly usage and data processing              |
| Amazon EBS                | Persistent storage             | Provisioned capacity                          |
| Data Transfer             | Network communication          | Cross-AZ and internet traffic                 |

---

## Compute Cost Optimization

### Auto Scaling Design

The application tier uses EC2 instances managed through an Auto Scaling Group.

Current configuration:

```text
Minimum Capacity: 2
Desired Capacity: 2
Maximum Capacity: 4
```

Benefits:

* Improved availability
* Automatic instance replacement
* Controlled resource growth
* Reduced over-provisioning risk

---

### Optimization Opportunities

Future improvements may include:

* Dynamic scaling policies
* Compute Savings Plans
* Reserved Instances
* AWS Graviton adoption
* Utilization-based instance right-sizing

Monitoring utilization metrics should always precede infrastructure resizing decisions.

---

## Networking Cost Optimization

### NAT Gateway Architecture

The environment deploys one NAT Gateway per Availability Zone.

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

---

### Design Rationale

The design improves availability by preventing a single Availability Zone dependency.

Benefits:

* Improved resilience
* Better fault isolation
* Availability during AZ failures

---

### Cost Tradeoff

A lower-cost alternative would use a single NAT Gateway.

Example:

```text
Private App Subnet AZ1
          │
          ▼
     NAT Gateway

          ▲
          │

Private App Subnet AZ2
```

Benefits:

* Lower monthly cost
* Fewer managed resources

Tradeoffs:

* Single point of failure
* Cross-AZ dependency
* Reduced resiliency

Decision:

Availability was prioritized over minimum cost.

---

## Database Cost Optimization

### Aurora MySQL

Aurora was selected to demonstrate managed database architecture.

Benefits:

* Managed operations
* Automated backups
* High availability capabilities
* MySQL compatibility
* Reduced administrative overhead

---

### Cost Considerations

Aurora costs are primarily influenced by:

* Instance runtime
* Storage utilization
* Backup retention
* Database I/O activity

---

### Development Recommendations

Development environments can reduce costs by:

* Using smaller instance classes
* Reducing backup retention periods
* Destroying environments when idle
* Limiting test data growth

---

### Production Recommendations

Production workloads should:

* Monitor CPU utilization
* Review connection counts
* Analyze storage growth
* Right-size instance classes
* Evaluate Aurora Serverless where appropriate

---

## Storage Optimization

### Amazon EBS

Application instances use EBS-backed storage.

Recommended practices:

* Use General Purpose SSD volumes
* Monitor storage consumption
* Remove unattached volumes
* Avoid excessive provisioning

Benefits:

* Balanced performance
* Predictable costs
* Operational simplicity

---

## Resource Lifecycle Management

Unused cloud resources create unnecessary costs.

The project includes automated environment destruction.

Command:

```bash
./destroy.sh
```

The cleanup workflow removes:

* Application Load Balancers
* Target Groups
* Auto Scaling Groups
* EC2 resources
* Aurora resources
* NAT Gateways
* Elastic IPs
* Route tables
* Security groups
* Subnets
* VPC resources
* IAM resources

This prevents development environments from generating ongoing charges.

---

## Resource Tagging Strategy

The platform uses resource tagging to improve governance and cost visibility.

Example tags:

```text
Project=aws-web-platform
Environment=prod
ManagedBy=aws-cli
```

Benefits:

* Cost allocation tracking
* Resource ownership visibility
* Governance reporting
* Automation targeting

---

## Cost Monitoring Strategy

Production environments should implement continuous cost monitoring.

---

### AWS Budgets

Used for:

* Monthly spending thresholds
* Cost notifications
* Budget tracking

---

### AWS Cost Explorer

Used for:

* Service-level cost analysis
* Usage trend identification
* Optimization opportunities

---

### AWS Cost Anomaly Detection

Used for:

* Unexpected spending changes
* Resource misconfiguration detection
* Early warning alerts

---

## Cost Controls Implemented

Current controls include:

* Automated environment teardown
* Controlled Auto Scaling limits
* Centralized configuration management
* Resource tagging
* Managed service selection
* Environment validation before deployment

---

## Future Cost Improvements

Potential enhancements include:

* AWS Budget alerts
* Scheduled environment shutdowns
* Cost estimation during deployment
* Infrastructure cost reporting
* Utilization dashboards
* Rightsizing recommendations
* Multi-environment cost allocation
* Compute Savings Plans evaluation
* Reserved Instance planning

---

## Architecture Cost Tradeoffs

### Availability vs Cost

Decision:

Deploy resources across multiple Availability Zones.

Benefit:

Improved fault tolerance and resiliency.

Tradeoff:

Additional infrastructure costs.

---

### Managed Services vs Self-Managed Services

Decision:

Use Aurora MySQL.

Benefit:

Reduced operational overhead and managed database features.

Tradeoff:

Higher service cost compared to self-managed databases.

---

### Security vs Cost

Decision:

Deploy application resources within private subnets behind NAT Gateways.

Benefit:

Reduced attack surface and stronger security posture.

Tradeoff:

Additional networking costs.

---

## Related Documentation

Additional architecture and governance references:

```text
docs/architecture/architecture-decisions.md
docs/deployment/deployment-guide.md
docs/governance/security.md
```

Relevant architectural decisions:

```text
ADR-003 Multi-AZ Subnet Architecture
ADR-006 Aurora MySQL Selection
ADR-007: Use NAT Gateways
ADR-012 Systems Manager Instead of SSH
```

---

## Design Goals

The cost optimization strategy was intentionally designed to demonstrate:

* Cost-aware AWS architecture
* Resource lifecycle management
* Operational governance
* Production-style tradeoff analysis
* AWS Well-Architected Framework principles
* Responsible cloud resource management

---

## Summary

The AWS Web Platform intentionally balances production-style architecture with cost awareness.

The goal is not simply to minimize AWS spending, but to understand the engineering tradeoffs between:

* Cost
* Security
* Availability
* Performance
* Operational complexity

Cost optimization is treated as an ongoing operational responsibility that evolves alongside the platform architecture.