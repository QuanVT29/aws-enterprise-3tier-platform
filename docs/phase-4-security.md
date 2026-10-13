# Phase 4: Security Hardening & Compliance Baseline

<br>

## 1. Architectural Scope & Objectives

The primary objective of Phase 4 is to enforce a **Defense-in-Depth (DiD)** posture across all architecture layers, hardening the infrastructure against common attack vectors and aligning with enterprise regulatory standards. This phase integrates perimeter filtering, cryptographic data isolation, automated secret life-cycle management, and continuous compliance auditing against the **CIS AWS Foundations Benchmark**.

Key capabilities delivered:
- **Perimeter Edge Defense:** AWS WAF v2 attached directly to the Public ALB, inspecting incoming Layer 7 traffic against OWASP Top 10 vulnerabilities, bad bots, and volumetric HTTP floods.
- **Cryptographic Control:** Customer Managed Keys (CMK) provisioned via AWS KMS to enforce envelope encryption (AES-256) across persistent block storage (EBS), database storage (RDS), S3 buckets, and CloudWatch logs.
- **Automated Credential Rotation:** Zero-downtime database credential rotation orchestrated by AWS Secrets Manager via an automated AWS Lambda rotation function.
- **Private Backbone Routing:** Gateway VPC Endpoints for Amazon S3, routing object storage traffic privately across the internal AWS network backbone to bypass NAT Gateways.
- **Continuous Compliance Governance:** Automated posture evaluation and drift detection configured via AWS Security Hub and AWS Config.

```text
  [ Internet / Threat Actors ]
               │
               ▼ (DDoS / SQLi / XSS Attack Traffic)
  [ AWS WAF v2 Web ACL ] ──(Inspect & Block: HTTP 403)──> [ Dropped at Edge ]
               │ (Legitimate Traffic Only)
               ▼
  [ Public ALB ] ──(TLS Termination / Private Transit)──> [ EC2 ASG Instances ]
                                                                │
                               ┌────────────────────────────────┴────────────────────────────────┐
                               ▼                                                                 ▼
                 [ AWS KMS (Customer Managed Key) ]                            [ Gateway VPC Endpoint ]
                 ├── Envelope Encryption for EBS Volumes                       └── Private S3 Backbone Transit
                 ├── AES-256 Encryption for RDS Multi-AZ
                 └── Log Group Cryptographic Protection
                               │
                               ▼
                 [ AWS Secrets Manager ] ──(Every 30 Days)──> [ Lambda Auto-Rotation ] ──> [ RDS PostgreSQL ]
```

