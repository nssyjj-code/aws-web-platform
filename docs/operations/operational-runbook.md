# Cloud Operations Runbook

## Overview

This runbook provides operational procedures for monitoring, troubleshooting, 
maintaining, and recovering the AWS Web Platform.

The objective is to provide repeatable operational guidance
that enables engineers to quickly identify issues, restore
service, and validate platform health.

Covered services:

* Application Load Balancer
* Target Groups
* Auto Scaling Groups
* EC2 Application Instances
* Aurora MySQL
* NAT Gateways
* VPC Networking
* Security Groups
* IAM Components

---

## Intended Audience

This runbook is intended for Cloud Engineers, Cloud Operations Engineers, 
Platform Engineers, and DevOps Engineers responsible for operating and maintaining the AWS Web Platform.

It provides standardized operational procedures for incident response, troubleshooting, 
maintenance, service recovery, and post-incident validation.

---

## Operational Principles

Operational procedures follow several guiding principles:

- Protect customer availability.
- Minimize Mean Time To Detect (MTTD).
- Minimize Mean Time To Recover (MTTR).
- Prefer automation over manual intervention.
- Validate all changes before closing incidents.
- Document findings for continuous improvement.

---

## Operational Objectives

This runbook supports:

* Incident response
* Service recovery
* Infrastructure troubleshooting
* Operational maintenance
* Post-incident validation

The primary goal is to reduce Mean Time To Detect (MTTD) and Mean Time To Recover (MTTR).

---

## Service Inventory

| Component                 | Responsibility                |
| ------------------------- | ----------------------------- |
| Application Load Balancer | Public traffic routing        |
| Target Group              | Application health validation |
| Auto Scaling Group        | Capacity management           |
| EC2 Instances             | Application processing        |
| Aurora MySQL              | Data persistence              |
| NAT Gateway               | Outbound connectivity         |
| Security Groups           | Traffic control               |
| IAM Roles                 | AWS service permissions       |

---

## Incident Severity Model

| Severity | Description               |
| -------- | ------------------------- |
| SEV-1    | Complete outage           |
| SEV-2    | Major service degradation |
| SEV-3    | Minor degradation         |
| SEV-4    | Informational             |

Severity should be determined based on customer impact and service availability.

---

### Escalation Guidelines

Escalate incidents when:

- Customer-facing services are unavailable.
- Multiple AWS services are affected.
- Data integrity may be compromised.
- Recovery exceeds established MTTR targets.
- Root cause cannot be identified within 30 minutes.

---

## Incident Response Workflow

When an incident occurs:

```text
Alert Received
       │
       ▼
Acknowledge Incident
       │
       ▼
Assess Impact
       │
       ▼
Investigate Root Cause
       │
       ▼
Apply Remediation
       │
       ▼
Validate Recovery
       │
       ▼
Document Findings
```

---

## Initial Incident Response Checklist

Perform the following checks before deep investigation.

### Initial Triage Checklist

Immediately after receiving an alert:

- Determine the incident severity.
- Identify affected services.
- Assess customer impact.
- Check for concurrent AWS service issues.
- Review recent infrastructure changes.
- Notify stakeholders if required.

### Verify AWS Identity

```bash
aws sts get-caller-identity
```

Confirm:

* Correct AWS account
* Correct IAM identity
* Expected permissions

---

### Verify Environment Health

Execute:

```bash
./verify.sh
```

Confirm:

* Load Balancer healthy
* Auto Scaling healthy
* Aurora available
* Target health passing

---

## Load Balancer Operations

### Verify ALB Health

```bash
aws elbv2 describe-load-balancers \
  --names "$ALB_NAME"
```

Expected:

```text
State = active
```

---

### Verify Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

Expected:

```text
TargetHealth.State = healthy
```

Investigate:

* unhealthy
* initial
* draining
* unused

---

### Common Causes

* Failed application startup
* Security group issues
* Health check path failures
* EC2 instance failures

---

## EC2 Operations

### Verify Running Instances

```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running"
```

Confirm:

* Running state
* Correct subnet placement
* Passed status checks

---

### Verify Instance Health

Review:

* CPU utilization
* Network traffic
* Disk activity
* Application processes

---

### Replace Failed Instance

Allow Auto Scaling to replace failed instances automatically.

Manual replacement:

```bash
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id <instance-id> \
  --should-decrement-desired-capacity false
```

---

## Auto Scaling Operations

### Verify ASG Status

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME"
```

Confirm:

```text
LifecycleState = InService
HealthStatus = Healthy
```

---

### Review Scaling Activities

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$ASG_NAME"
```

Review:

* Launch failures
* Scaling events
* Capacity changes

---

### Instance Refresh

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME"
```

Use when:

* Launch template changes
* Application updates
* Fleet replacement

---

## Aurora Operations

### Verify Cluster Status

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_IDENTIFIER"
```

Expected:

```text
Status = available
```

---

### Verify Writer Instance

```bash
aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE_IDENTIFIER"
```

Expected:

```text
DBInstanceStatus = available
```

---

### Database Connectivity Validation

Verify:

* Aurora endpoint
* Security group configuration
* Credentials
* Application connectivity

Expected traffic flow:

```text
Application Security Group
          │
          ▼
Database Security Group
          │
          ▼
Aurora MySQL
```

---

## Networking Operations

### Verify Internet Gateway

```bash
aws ec2 describe-internet-gateways
```

Confirm:

* Attached to VPC
* Active routes exist

Expected route:

```text
0.0.0.0/0 → Internet Gateway
```

---

### Verify NAT Gateway

```bash
aws ec2 describe-nat-gateways
```

Expected:

```text
State = available
```

Confirm:

* Elastic IP attached
* Route tables configured

Expected private route:

```text
0.0.0.0/0 → NAT Gateway
```

---

## Security Operations

### Security Group Validation

Expected traffic path:

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

Verify:

* No public SSH access
* No public database access
* Least-privilege rules remain intact

---

## Operational Maintenance

### Daily Tasks

Review:

* CloudWatch alarms
* Target health
* Aurora status
* Auto Scaling health

---

### Weekly Tasks

Review:

* Resource utilization
* Security group changes
* Scaling activity
* Infrastructure drift

---

### Monthly Tasks

Review:

* Cost trends
* Backup retention
* Capacity planning
* Architecture improvement opportunities

---

## Recovery Procedures

### Application Recovery

Steps:

1. Verify ALB health
2. Verify target health
3. Review EC2 health
4. Replace failed instances if required
5. Validate application response

---

### Database Recovery

Steps:

1. Verify Aurora status
2. Review events
3. Perform failover if required
4. Restore snapshot if necessary
5. Validate connectivity

Additional guidance:

```text
docs/operations/disaster-recovery.md
```

---

### Infrastructure Recovery

Redeploy platform resources:

```bash
./deploy.sh
```

Validate:

```bash
./verify.sh
```

---

## Post-Incident Activities

Following service restoration:

1. Document root cause
2. Document remediation steps
3. Identify preventative improvements
4. Update runbooks if necessary
5. Update monitoring if gaps were identified

Incident examples:

```text
docs/operations/incident-response-scenarios.md
```

---

### Planned Maintenance

Planned maintenance activities should minimize operational
risk and be performed using repeatable validation procedures.

Before performing planned maintenance:

1. Validate current platform health.
2. Notify stakeholders.
3. Create backups or snapshots if applicable.
4. Implement the planned change.
5. Execute verification procedures.
6. Monitor for unexpected behavior.
7. Update operational documentation if required.

---

## Related Documentation

Operational references:

```text
docs/operations/monitoring-strategy.md
docs/operations/disaster-recovery.md
docs/operations/incident-scenarios.md
```

Architecture references:

```text
docs/architecture/architecture.md
docs/architecture/network-design.md
```

---

## Design Goals

This operational runbook was intentionally designed to demonstrate:

* Production incident response
* Operational troubleshooting
* Infrastructure recovery
* Standardized operational procedures
* Cloud operations best practices
* Repeatable service restoration workflows

---

## Summary

This runbook provides operational guidance for maintaining, troubleshooting, 
recovering, and validating the AWS Web Platform.

The objective is not only to deploy infrastructure, but to operate cloud services 
using repeatable procedures that improve reliability, reduce recovery time, and support production-style operations.