# AWS Authentication

## Overview

This document describes the authentication and authorization approach used by the AWS Web Platform.

The project provisions AWS infrastructure through AWS CLI automation and authenticates using locally configured AWS credentials during deployment. This approach is appropriate for local development but should be replaced with temporary credentials through IAM Identity Center or role assumption in enterprise environments.

The design intentionally separates:

* Human authentication
* Infrastructure authentication
* Application authentication
* Future CI/CD authentication

The implementation prioritizes security, credential separation, and AWS best practices while remaining practical for a personal development environment.

---

## Authentication Architecture

The platform uses different authentication mechanisms depending on the actor performing actions within AWS.

```text
Developer
    │
    ▼
AWS CLI Credentials
    │
    ▼
AWS API

EC2 Instance
    │
    ▼
IAM Role
    │
    ▼
AWS Services

Future CI/CD
    │
    ▼
OIDC Federation
    │
    ▼
AWS IAM Role
```

---

## Development Authentication Model

This project uses:

* AWS CLI v2
* Local AWS credential profiles
* AWS shared credentials file
* AWS shared configuration file

Authentication is resolved through the AWS CLI credential provider chain.

Deployment scripts never contain embedded credentials.

---

## Local AWS Configuration

Configure credentials:

```bash
aws configure
```

Example:

```text
AWS Access Key ID     = ********************
AWS Secret Access Key = ********************
Default region        = us-east-1
Output format         = json
```

AWS stores configuration locally:

```text
~/.aws/credentials
~/.aws/config
```

These files are intentionally excluded from source control.

---

## Identity Verification

Before deployment begins, automation validates the active AWS identity.

Validation occurs through:

```bash
aws sts get-caller-identity
```

Example response:

```json
{
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/developer",
  "UserId": "AIDxxxxxxxxxxxx"
}
```

Deployment should only proceed after confirming:

* Correct AWS account
* Correct IAM identity
* Correct AWS region
* Expected permissions

---

## Deployment Authentication Workflow

During deployment:

```text
Developer
    │
    ▼
AWS CLI
    │
    ▼
AWS Credential Provider Chain
    │
    ▼
AWS APIs
```

The deployment scripts rely entirely on AWS-native authentication mechanisms.

Credentials are never:

* Hardcoded
* Stored in deployment scripts
* Stored in configuration files
* Committed to source control

---

## Infrastructure Authentication

Application instances do not use AWS access keys.

Instead, EC2 instances receive permissions through an IAM role.

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

## Systems Manager Access

The platform uses AWS Systems Manager permissions through:

```text
AmazonSSMManagedInstanceCore
```

This enables:

* Session Manager access
* Inventory collection
* Secure administration

Benefits:

* No inbound SSH required
* Reduced attack surface
* Centralized access auditing
* No SSH key management

---

## Security Controls

Several controls protect authentication credentials.

### Source Control Protection

The repository never stores:

* Access keys
* Secret keys
* Session tokens
* Database credentials

---

### MFA Protection

The AWS account uses Multi-Factor Authentication (MFA).

Benefits:

* Reduced credential theft risk
* Additional account protection
* AWS security best practice

---

### Credential Separation

Authentication is separated by purpose.

| Function                  | Authentication Method |
| ------------------------- | --------------------- |
| Developer Access          | AWS CLI Credentials   |
| Infrastructure Deployment | IAM User / Profile    |
| EC2 Access                | IAM Role              |
| Session Management        | Systems Manager       |
| Future CI/CD              | OIDC Federation       |

---

## Why This Approach Was Chosen

For a personal development environment, locally configured AWS credentials provide:

* Simplicity
* Fast deployment iteration
* Reduced setup complexity
* Easy troubleshooting

This approach allows focus on AWS infrastructure design rather than identity platform administration.

---

## Production Considerations

The authentication model used for this project is appropriate for development and portfolio environments but would not be the preferred long-term production solution.

---

### IAM Identity Center (AWS SSO)

Recommended for enterprise environments.

Benefits:

* Centralized identity management
* Temporary credentials
* Improved auditing
* Simplified access revocation

---

### IAM Role Assumption

Recommended for administrative access.

Benefits:

* No long-lived access keys
* Temporary credentials
* Reduced credential exposure

---

### CI/CD Federation

Future deployment automation could use OpenID Connect (OIDC).

Architecture:

```text
GitHub Actions
        │
        ▼
OpenID Connect
        │
        ▼
AWS IAM Role
        │
        ▼
AWS Resources
```

Benefits:

* No stored AWS secrets
* Temporary credentials
* Improved security posture
* Reduced operational overhead

---

## Future Improvements

Potential authentication enhancements include:

* AWS IAM Identity Center
* GitHub OIDC federation
* AWS Secrets Manager integration
* Multi-account deployment support
* Automated credential auditing
* Organization-wide identity management

---

## Related Documentation

Additional security and operational references:

```text
docs/governance/security.md
docs/architecture/architecture-decisions.md
docs/deployment/deployment-guide.md
```

Relevant architecture decisions:

```text
ADR-008 Security Group Referencing
ADR-012 Systems Manager Instead of SSH
```

---

## Lessons Learned

This project reinforced several AWS security principles.

* Never store credentials in source control
* Verify identity before provisioning resources
* Prefer IAM roles over embedded credentials
* Use temporary credentials whenever possible
* Separate human and workload authentication
* Leverage AWS-native authentication mechanisms

---

## Design Goals

The authentication model was intentionally designed to demonstrate:

* Secure AWS authentication
* Separation of human and workload identities
* IAM role-based access
* AWS best practices
* Credential management
* Production-ready authentication patterns

---

## Summary

The AWS Web Platform uses AWS-native authentication and authorization mechanisms that emphasize credential separation, least privilege, and operational security.

The implementation intentionally balances practical development workflows with production-oriented security principles while demonstrating authentication patterns commonly used in AWS environments.