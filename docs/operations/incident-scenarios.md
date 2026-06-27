# Incident Response Playbook

## Overview

This document contains simulated production incidents performed against the AWS Web Platform.

The purpose of these scenarios is to demonstrate operational troubleshooting, incident response, root cause analysis, and recovery procedures.

Each incident follows a structured operational workflow:

1. Detection
2. Triage
3. Investigation
4. Root Cause Identification
5. Remediation
6. Recovery Validation
7. Preventative Improvements

---

# Incident Severity Definitions

| Severity | Description       | Example Impact                      |
| -------- | ----------------- | ----------------------------------- |
| SEV-1    | Critical outage   | Complete application unavailability |
| SEV-2    | Major degradation | Significant customer impact         |
| SEV-3    | Minor degradation | Limited functionality affected      |
| SEV-4    | Informational     | No customer impact                  |

---

# Incident 001 – Application Load Balancer Returning HTTP 503 Errors

## Severity

SEV-2

## Detection

Source:

```text
CloudWatch Alarm
```

Alert:

```text
UnHealthyHostCount > 0
```

Customer Impact:

```text
Users unable to access application
```

---

## Scenario

Users report the website is unavailable.

Requests to the Application Load Balancer return:

```text
HTTP 503 Service Unavailable
```

---

## Incident Timeline

```text
06:00 Alarm Triggered
06:03 Incident Acknowledged
06:07 Investigation Started
06:15 Root Cause Identified
06:22 Instance Replaced
06:28 Service Restored
06:40 Incident Closed
```

---

## Investigation

Verify ALB health:

```bash
aws elbv2 describe-load-balancers \
  --names "$ALB_NAME"
```

Result:

```text
Load Balancer Status = active
```

Check target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

Finding:

```text
TargetHealth.State = unhealthy
```

---

## Root Cause

Application instances failed health checks.

Possible causes:

* Application process stopped
* Incorrect health check endpoint
* Security group misconfiguration
* Launch template startup failure

---

## Resolution

Replace unhealthy instance:

```bash
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id <instance-id> \
  --should-decrement-desired-capacity false
```

Auto Scaling launched replacement capacity.

---

## Recovery Validation

Validate:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

Expected:

```text
TargetHealth.State = healthy
```

---

## Action Items

* Add synthetic monitoring
* Create application health dashboard
* Improve startup validation checks

---

# Incident 002 – Database Connectivity Failure

## Severity

SEV-2

## Detection

Source:

```text
Application Error Logs
```

Alert:

```text
Database Connection Failures
```

---

## Scenario

Application instances remain healthy but user requests fail.

Application logs show:

```text
Unable to connect to database
```

---

## Incident Timeline

```text
11:12 Alert Received
11:15 Investigation Started
11:22 Security Group Issue Identified
11:27 Rule Restored
11:30 Service Recovered
```

---

## Investigation

Verify Aurora cluster:

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_IDENTIFIER"
```

Result:

```text
Status = available
```

Validate security groups.

Expected communication:

```text
APP Security Group
        │
        ▼
DB Security Group
TCP 3306
```

---

## Root Cause

Database security group rule was removed.

---

## Resolution

Restore rule:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <db-sg-id> \
  --protocol tcp \
  --port 3306 \
  --source-group <app-sg-id>
```

---

## Recovery Validation

Validate connectivity:

```bash
mysql -h <endpoint> -u <user>
```

Application errors resolved.

---

## Action Items

* Enable AWS Config rule monitoring
* Implement security group drift detection
* Add automated validation checks

---

# Incident 003 – Private Instances Cannot Reach the Internet

## Severity

SEV-3

## Detection

Source:

```text
Application Logs
```

Symptoms:

* Failed package downloads
* Failed API calls
* Update failures

---

## Scenario

Private application instances cannot access external services.

---

## Investigation

Check NAT Gateway status:

```bash
aws ec2 describe-nat-gateways
```

Expected:

```text
State = available
```

Check route tables:

```bash
aws ec2 describe-route-tables
```

Expected route:

```text
0.0.0.0/0 → NAT Gateway
```

---

## Root Cause

Private application route table missing NAT route.

---

## Resolution

Restore route:

```bash
aws ec2 create-route \
  --route-table-id <route-table-id> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <nat-id>
```

---

## Recovery Validation

Verify outbound connectivity:

```bash
curl https://aws.amazon.com
```

Expected:

```text
HTTP 200
```

---

## Action Items

* Add route validation to verification scripts
* Add CloudWatch route monitoring
* Implement drift detection

---

# Incident 004 – Auto Scaling Group Not Launching Replacement Capacity

## Severity

SEV-2

## Detection

Source:

```text
CloudWatch Alarm
```

Alert:

```text
GroupInServiceInstances < DesiredCapacity
```

---

## Scenario

Failed instances are not replaced automatically.

---

## Investigation

Check ASG:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME"
```

Review scaling activities:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$ASG_NAME"
```

---

## Possible Root Causes

* Invalid launch template
* Missing IAM permissions
* Unavailable AMI
* Capacity constraints

---

## Resolution

Correct dependency issue.

Refresh instances:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME"
```

---

## Recovery Validation

Verify:

```bash
Desired Capacity = Running Capacity
```

---

## Action Items

* Add launch template validation
* Implement deployment testing
* Add scaling activity alarms

---

# Incident 005 – Environment Destruction Failure

## Severity

SEV-3

## Detection

Source:

```text
Destroy Script Output
```

Error:

```text
ResourceInUse
```

---

## Scenario

Destroy automation fails while removing infrastructure.

---

## Investigation

Review ALB dependencies:

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn <alb-arn>
```

Finding:

```text
Target Group attached to Listener
```

---

## Root Cause

Dependency ordering issue.

Incorrect:

```text
Delete Target Group
      │
      ▼
Delete Listener
```

Correct:

```text
Delete Listener
      │
      ▼
Delete Target Group
```

---

## Resolution

Destroy workflow updated to:

1. Delete listeners
2. Delete ALB
3. Delete target groups

---

## Recovery Validation

Destroy process completed successfully.

---

## Action Items

* Expand dependency validation
* Improve destroy script logging
* Add cleanup integration testing

---

# Lessons Learned

Operational excellence requires more than successful deployments.

Reliable cloud platforms require:

* Monitoring
* Alerting
* Recovery procedures
* Dependency awareness
* Operational runbooks
* Failure testing
* Continuous improvement

The objective is not eliminating all failures.

The objective is reducing Mean Time To Detect (MTTD) and Mean Time To Recover (MTTR).

These scenarios demonstrate how production-style incidents can be detected, investigated, resolved, and prevented using AWS operational best practices.