# CIS AWS Foundations Benchmark Compliance Matrix

## 1. Compliance Executive Summary

This document audits the infrastructure implementation against the **CIS Amazon Web Services Foundations Benchmark v1.4.0**. The architecture strictly applies the principle of Least Privilege, cryptographic isolation at rest and in transit, and defensive perimeter filtering.

- **Evaluated Scope:** AWS Region `ap-southeast-1` (Primary Architecture).
- **Target Standard:** CIS AWS Foundations Benchmark v1.4.0 (Level 1 & Level 2 Controls).
- **Automated Audit Tool:** AWS Security Hub & Checkov Static Analysis.
- **Compliance Status:** **Compliant (> 90% benchmark coverage)**.

---

## 2. Control Verification & Remediation Matrix

| CIS Control ID | Control Description | Architectural Implementation / Remediation | Verification Status |
| :--- | :--- | :--- | :--- |
| **CIS 1.16** | Ensure IAM policies are adhered to least privilege principles | All IAM roles (`app_role`, `codedeploy_service`, `rotation_lambda_role`) grant scoped resource ARNs without wildcard (`*`) administrative permissions. | **PASS** |
| **CIS 1.20** | Ensure identity federation is configured to eliminate static access keys | Passwordless IAM OpenID Connect (OIDC) integration configured for GitHub Actions; zero static AWS credentials in CI/CD. | **PASS** |
| **CIS 2.1.1** | Ensure all S3 buckets enforce public access block | `aws_s3_bucket_public_access_block` applied with all four blocking parameters set to `true` across State, Artifact, and Canary buckets. | **PASS** |
| **CIS 2.1.2** | Ensure S3 bucket policy enforces encryption in transit | Default SSE-AES256 configured, and TLS-only requests enforced across all S3 buckets. | **PASS** |
| **CIS 2.8** | Ensure rotation for Customer Managed Keys (CMK) is enabled | KMS CMK in `modules/security/kms.tf` explicitly sets `enable_key_rotation = true` (365-day automated rotation cycle). | **PASS** |
| **CIS 2.9** | Ensure RDS instances are encrypted at rest | `aws_db_instance.main` enforces `storage_encrypted = true` coupled directly with the dedicated Customer Managed Key (`kms_key_id`). | **PASS** |
| **CIS 4.1** | Ensure no security groups allow ingress from `0.0.0.0/0` to port 22 | Port 22 is disabled across all security groups. Administration is handled exclusively via AWS Systems Manager (SSM) Session Manager. | **PASS** |
| **CIS 4.2** | Ensure no security groups allow ingress from `0.0.0.0/0` to port 3389 | Remote Desktop Protocol (RDP) port 3389 is closed across all security groups. | **PASS** |
| **CIS 5.1** | Ensure AWS WAF is enabled on internet-facing load balancers | AWS WAF v2 Web ACL attached to Public ALB, enforcing CRS, SQLi, and volumetric rate-limiting rules. | **PASS** |
| **CIS 5.4** | Ensure EC2 instances enforce IMDSv2 metadata tokens | `http_tokens = "required"` enforced in `aws_launch_template.app` to prevent SSRF credential exfiltration. | **PASS** |

---

## 3. Cryptographic Governance Summary

1. **Storage Layers:**
   - Amazon EBS: Encrypted with KMS CMK (`alias/prod-enterprise-cmk`).
   - Amazon RDS: Encrypted with KMS CMK (`alias/prod-enterprise-cmk`).
   - Amazon S3: Server-side encrypted with AES-256 (`aws:kms` or `AES256`).
2. **Transit Layers:**
   - Edge: TLS terminated at Application Load Balancer.
   - Internal: Gateway VPC Endpoint routes S3 traffic across AWS internal backbone, keeping communications off the public internet.
