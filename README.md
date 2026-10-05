# Production-Ready AWS Enterprise 3-Tier Architecture: DevSecOps, Security Hardening & Multi-Region Resilience

[![AWS Provider](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform_v1.9+-844FBA?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions_OIDC-2088FF?style=flat&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Security Scanners](https://img.shields.io/badge/Shift--Left-Trivy_%7C_Checkov_%7C_TFLint-blueviolet?style=flat)](https://github.com/)
[![Compliance](https://img.shields.io/badge/Security-CIS_AWS_Foundations_Benchmark-success?style=flat&logo=shield)](https://aws.amazon.com/security-hub/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An end-to-end, production-grade cloud infrastructure engineered on Amazon Web Services (AWS) using **Terraform (IaC)**. Designed around the six pillars of the **AWS Well-Architected Framework**, this platform features Multi-AZ high availability, Zero-Trust administration, a Shift-Left DevSecOps delivery pipeline (via IAM OIDC), comprehensive CloudWatch observability, defense-in-depth perimeter security (AWS WAF v2 & KMS), and cross-region disaster recovery (Route 53 DNS Failover & RDS Read Replica).

---

## 📌 Executive Summary & Key Metrics

This project demonstrates the transition from traditional, monolithic cloud deployments to an automated, auditable, and resilient enterprise ecosystem.

| Metric / Objective | Design Target | Verified Outcome |
| :--- | :--- | :--- |
| **High Availability (HA)** | Multi-AZ auto-healing | Zero single points of failure across compute & data tiers |
| **Infrastructure Deployment** | 100% Automated IaC | Complete stack orchestrated via modular Terraform with remote state locking |
| **Administrative Access** | Zero Open Inbound Ports | 100% SSH-less instance management via **AWS Systems Manager (SSM)** |
| **Deployment Downtime** | Zero-Downtime Deployment | 0% HTTP 5xx errors during rollouts via CodeDeploy + ALB health checks |
| **Authentication Security** | Zero Static Credentials | Ephemeral, short-lived AWS STS tokens via **IAM OpenID Connect (OIDC)** |
| **Recovery Point Objective (RPO)** | Near Real-Time (< 60s) | Verified **~5–15 seconds** using asynchronous RDS Cross-Region Replication |
| **Recovery Time Objective (RTO)** | < 15 minutes | Verified **~6–8 minutes** using automated pilot-light failover scripts |
| **Compliance Posture** | AWS CIS Benchmark | Automated remediation yielding >90% compliance score in Security Hub |

---

## 🏗️ Architecture Blueprint

### 1. High-Level Enterprise Architecture
The system utilizes a 3-tier decoupled design spanning across multiple Availability Zones in the primary region (`ap-southeast-1`), with an active-standby disaster recovery strategy configured in the secondary region (`ap-southeast-2`).

![System Architecture](docs/images/architecture-diagram.png)

### 2. End-to-End Implementation & Delivery Pipeline
Infrastructure, security gates, application deployment, observability, and failover pathways are organized across five systematic phases:

![Pipeline Blueprint](docs/images/pipeline-diagram.png)

---

## 🧭 5-Phase Implementation Breakdown

### [Phase 1: Multi-AZ High Availability Foundation (IaC & Zero Trust)](docs/phase-1-foundation.md)
*   **Networking Isolation:** Modular VPC (`10.0.0.0/16`) spanning 2 Availability Zones. Segmented into **Public Subnets** (ALBs, Dual NAT Gateways), **Private Application Subnets** (EC2 ASG), and **Isolated Database Subnets** (strict non-routable tables with zero internet/NAT access).
*   **Compute & Load Balancing:** Application Load Balancer (ALB) enforcing sticky sessions and strict health checking. Auto Scaling Group (ASG) powered by Launch Templates using cost-efficient **AWS Graviton processors (`t4g.micro`)**.
*   **Database Tier:** Amazon RDS Multi-AZ deployment (PostgreSQL/MySQL) offering synchronous physical replication and automatic failover in under 60 seconds.
*   **Zero-Trust Management:** Security Groups with no inbound port 22 (SSH). Administrative operations are handled exclusively through **AWS Systems Manager (SSM) Session Manager** with complete command logging.
*   **State Management:** Terraform remote backend anchored in an S3 bucket (versioned, SSE-KMS encrypted) paired with DynamoDB state locking.

### [Phase 2: Shift-Left Security & GitOps CI/CD Pipeline](docs/phase-2-cicd.md)
*   **Identity Federation (OIDC):** Passwordless GitHub Actions authentication via AWS IAM OpenID Connect (OIDC), eliminating the need for long-lived static AWS access keys.
*   **Shift-Left Static Analysis:** Every Pull Request runs automated CI security gates:
    *   `tflint`: Enforces Terraform syntax conventions and provider-specific best practices.
    *   `checkov` & `tfsec`: Scans IaC definitions for security misconfigurations and compliance violations.
    *   `trivy`: Analyzes application dependencies and base system packages for known CVEs.
*   **Controlled Deployment:** Automated deployment to Staging environment followed by a GitHub Environment **Manual Approval Gate** before production rollout.
*   **Zero-Downtime Rollouts:** AWS CodeDeploy integration with ALB target groups executing rolling updates, traffic shifting, and automatic rollback on elevated error rates.

### [Phase 3: Production Observability & SRE Incident Response](docs/phase-3-observability.md)
*   **Deep Telemetry:** CloudWatch Unified Agent embedded in EC2 Golden AMIs to publish system-level metrics (RAM utilization, swap usage, disk space, and IOPS).
*   **Dashboard-as-Code:** Unified CloudWatch Dashboard provisioned via Terraform, consolidating edge metrics (ALB latency, 4xx/5xx counts), compute health, and RDS connection pools.
*   **Synthetic Monitoring:** CloudWatch Synthetics Canary executing end-to-end user heartbeat requests every 60 seconds against critical endpoints.
*   **Real-Time ChatOps:** CloudWatch Alarms dispatching alerts through Amazon SNS to **AWS Chatbot**, streaming rich incident alerts directly into Slack/Discord channels.
*   **SRE Runbook:** Standard Operating Procedures (SOPs) detailing clear escalation paths and troubleshooting checklists for incident remediation.

### [Phase 4: Security Hardening & Compliance Baseline](docs/phase-4-security.md)
*   **Perimeter Defense:** **AWS WAF v2** attached directly to the Public ALB, applying:
    *   Rate-based throttling rules (anti-DDoS / brute force protection).
    *   AWS Managed Core Rule Set (CRS) and Known Bad Inputs.
    *   OWASP Top 10 mitigation rules (SQLi, XSS, Path Traversal).
*   **Comprehensive Data Protection:** Customer Managed Keys (CMK) generated in **AWS KMS** enforcing AES-256 encryption across EBS storage volumes, RDS databases, S3 buckets, and CloudWatch log groups.
*   **Automated Credential Rotation:** Dynamic database credential generation managed by **AWS Secrets Manager**, rotated automatically every 30 days via a custom AWS Lambda execution.
*   **Private VPC Endpoints:** Gateway Endpoints provisioned for Amazon S3, routing storage traffic through internal AWS backbone networks without passing through NAT Gateways.
*   **Continuous Governance:** Continuous compliance tracking via **AWS Security Hub** (CIS AWS Foundations Benchmark v1.4.0), **AWS GuardDuty** (threat detection), and **AWS Config Rules**.

### [Phase 5: Disaster Recovery & Business Continuity](docs/phase-5-disaster-recovery.md)
*   **Cross-Region Data Replication:**
    *   **Data Tier:** Asynchronous replication to an Amazon RDS Cross-Region Read Replica in Sydney (`ap-southeast-2`).
    *   **Object Tier:** Automated S3 Cross-Region Replication (CRR) for static assets and snapshots.
*   **Intelligent DNS Failover:** Amazon Route 53 with automated Health Checks and Failover Routing Policies:
    *   *Scenario 1 (Cost-Optimized):* Instant DNS redirection to an S3 Static Website serving a maintenance fallback page with zero standby compute expenses.
    *   *Scenario 2 (Pilot Light / Warm Standby):* One-click DR script executing automated RDS Read Replica promotion and rapid ASG instance spin-up from pre-baked AMIs.
*   **Empirical DR Drill:** Rigorous regional failover tests measuring and validating exact RTO and RPO metrics against SLA commitments.

---

## 📂 Repository Layout

```text
aws-enterprise-3tier-platform/
├── .github/
│   └── workflows/
│       ├── iac-security-scan.yml     # Linter & SAST gates (tflint, checkov, trivy)
│       └── release-deploy.yml         # CI/CD deployment with manual environment gates
│
├── app/                              # Cloud-Native Diagnostic Application
│   ├── src/                          # Lightweight backend reading instance metadata & RDS state
│   ├── scripts/                      # CodeDeploy application lifecycle hooks
│   └── appspec.yml                   # AWS CodeDeploy deployment specification
│
├── terraform/                        # Modular Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/                      # Multi-AZ VPC, subnets, route tables, NAT GWs
│   │   ├── alb/                      # ALB, target groups, listeners, health checks
│   │   ├── asg/                      # Launch templates (Graviton), ASG policies
│   │   ├── rds/                      # RDS Multi-AZ DB instance, parameter & subnet groups
│   │   ├── observability/            # CloudWatch Dashboards, Canaries, Metric Filters, Alarms
│   │   ├── security/                 # AWS WAF v2, KMS CMK, Secrets Manager, VPC Endpoints
│   │   └── disaster-recovery/        # Route 53 failover records, S3 CRR, cross-region replica
│   │
│   ├── environments/
│   │   ├── primary-singapore/        # Root Terraform for Region A (Phase 1, 3, 4)
│   │   └── dr-sydney/                # Root Terraform for Region B (Phase 5)
│   └── global/                       # IAM OIDC federation and shared Route 53 zones
│
├── docs/                             # Engineering Documentation & Audit Proofs
│   ├── images/                       # Architectural diagrams and telemetry screenshots
│   ├── incident-runbook.md           # Operational Runbook for SRE on-call teams
│   ├── security-baseline.md          # CIS Benchmark remediation and findings report
│   └── dr-drill-report.md            # Regional disaster simulation data (RTO/RPO calculation)
│
├── scripts/                          # Operational & FinOps Automation
│   ├── quick-deploy.sh               # Local deployment wrapper
│   ├── quick-destroy.sh              # Clean-up script to terminate resources and reduce cost
│   └── trigger-dr-failover.sh        # One-click disaster recovery failover automation
│
└── README.md                         # Project Master Documentation
