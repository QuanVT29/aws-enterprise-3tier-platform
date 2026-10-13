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



<br>



## 2. Security Hardening Specifications

### 2.1 Perimeter Filtering (AWS WAF v2)

- Attachment Point: Associated directly with the Public Application Load Balancer via the aws_wafv2_web_acl_association hook established in Phase 1.

- Default Action: Allow (with granular rule-level inspection).

- Managed Rule Sets (MRS):

+AWSManagedRulesCommonRuleSet (CRS): Mitigates common web application vulnerabilities (Path Traversal, LFI/RFI, Command Injection).

+AWSManagedRulesKnownBadInputsRuleSet: Blocks requests with invalid host headers and exploit payloads.

+AWSManagedRulesSQLiRuleSet: Inspects request query strings, URI paths, and request bodies for SQL Injection patterns.

- Custom Rate-Based Rule:

+Evaluates client IP request counts within a 5-minute sliding window.

+Rate limit threshold: 300 requests per 5 minutes.

+Action on breach: Temporary Block returning HTTP 403 Forbidden.



### 2.2 Cryptographic Key Management (AWS KMS)

- Key Type: Symmetric Customer Managed Key (CMK) using SYMMETRIC_DEFAULT (AES-256-GCM).

- Key Policy: Adheres strictly to Least Privilege, separating key administrative roles from runtime cryptographic usage roles (kms:Encrypt, kms:Decrypt, kms:GenerateDataKey*).

- Key Rotation: Automatic annual key rotation enabled (enable_key_rotation = true).

- Enforcement Scope:

+Amazon EBS root/data volumes attached to EC2 compute nodes.

+Amazon RDS Multi-AZ storage engine.

+S3 artifact and canary storage buckets.

+CloudWatch Log Groups.


### 2.3 Automated Secret Life-Cycle (AWS Secrets Manager)

- Master database credentials (prod-rds-credentials) configured with automated 30-day rotation.

- Rotation is orchestrated by a dedicated serverless function running inside the Private App Subnets with direct security group access to the RDS database.

- Uses the standard 4-step rotation protocol: createSecret, setSecret, testSecret, and finishSecret.



### 2.4 Private Network Transit (VPC Endpoints)

- Gateway VPC Endpoint: Attached to the primary VPC for Amazon S3.

- Routes S3 traffic directly over the AWS global network backbone, eliminating NAT Gateway data processing fees and keeping data traffic off the public internet.

- Applied automatically to both Public and Private route tables.


<br>



## 3. Security Directory Layout
```
aws-enterprise-3tier-platform/
├── terraform/
│   ├── modules/
│   │   ├── security/
│   │   │   ├── main.tf                 # IAM Roles, Secrets Manager (from Phase 1)
│   │   │   ├── kms.tf                  # KMS Customer Managed Key & Key Policy
│   │   │   ├── waf.tf                  # AWS WAF v2 Web ACL & Rule Sets
│   │   │   ├── secrets_rotation.tf     # Lambda rotation function & rotation schedule
│   │   │   ├── vpc_endpoints.tf        # S3 Gateway VPC Endpoint
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf              # WAF Web ACL ARN, KMS Key ARN
│   │   │
│   │   └── alb/
│   │       └── main.tf                 # Consumes waf_acl_arn variable (Plug & Play)
│   │
│   └── environments/
│       └── primary-singapore/
│           ├── main.tf                 # Links module.security outputs to module.alb
│           └── outputs.tf
│
├── docs/
│   ├── images/
│   │   ├── phase4-security-architecture.png
│   │   ├── proof-waf-sqli-block.png
│   │   ├── proof-waf-rate-limiting.png
│   │   ├── proof-kms-cmk-encryption.png
│   │   ├── proof-secrets-rotation.png
│   │   └── proof-cis-benchmark-score.png
│   └── security-baseline.md            # CIS AWS Benchmark compliance report
```


<br>



## 4. Layered Defense Architecture (Defense-in-Depth)

The security model implements protections across five distinct control planes:

LayerSecurity MechanismThreat AddressedCompliance ControlEdge / PerimeterAWS WAF v2 (CRS, SQLi, Rate Limit)OWASP Top 10, Layer 7 DDoS, Web ScrapersCIS AWS 5.1 / NIST SC-7Network TransitSecurity Group Chaining + VPC EndpointsLateral movement, Data exfiltration over internetCIS AWS 5.2 / NIST AC-4Compute NodeIMDSv2 Enforced + SSM Session ManagerSSRF metadata theft, Open port exploitationCIS AWS 5.4 / NIST IA-2Data at RestAWS KMS CMK (AES-256)Unauthorized disk access, Physical storage theftCIS AWS 2.8 / NIST SC-13Identity & SecretsAWS Secrets Manager (Auto-Rotation)Credential compromise, Hardcoded secretsCIS AWS 1.14 / NIST IA-5



<br>


## 5. Verification & Testing Scenarios

### Scenario 1: WAF Layer 7 Inspection — SQL Injection & XSS Blocking

- Objective: Verify that malicious HTTP requests matching OWASP Top 10 attack signatures are dropped at the perimeter before reaching the Application Load Balancer target pool.

- Execution:

1. Execute a simulated SQL Injection payload via curl targeting the ALB DNS:
```
ALB_URL=$(terraform -chdir=terraform/environments/primary-singapore output -raw alb_public_dns)
curl -i -s "http://$ALB_URL/?id=1'%20OR%20'1'='1"
```

2. Execute a simulated Cross-Site Scripting (XSS) payload:
```
curl -i -s "http://$ALB_URL/?search=<script>alert('xss')</script>"
```

- Verification Criteria:

+The HTTP response status returns 403 Forbidden.

+The response body indicates blocking by AWS WAF.

+The AWS WAF Console displays matching sampled requests tagged under AWS-AWSManagedRulesSQLiRuleSet and AWS-AWSManagedRulesCommonRuleSet.



<br>


### Scenario 2: Rate-Based Throttling / Layer 7 Anti-DDoS

- Objective: Prove that aggressive request bursts exceeding the defined threshold (300 requests/5 minutes) are automatically throttled.

- Execution:

1. Launch a high-frequency HTTP request loop targeting the ALB:
```
for i in {1..350}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_URL/healthz")
  echo -ne "Request $i: HTTP $STATUS\r"
  sleep 0.1
done
echo ""
```

- Observations & Measured Result:

+Initial requests succeed with HTTP 200.

+Once the threshold is breached, subsequent requests from the client IP receive HTTP 403 Forbidden.

+CloudWatch metric BlockedRequests for the Web ACL reflects an immediate upward spike.


<br>

### Scenario 3: Cryptographic Envelope Encryption via KMS CMK

- Objective: Verify that persistent storage layers are encrypted using a dedicated Customer Managed Key rather than default AWS-managed shared keys.

- Execution:

1. Inspect the RDS Database configuration via AWS CLI:
```
aws rds describe-db-instances \
  --db-instance-identifier prod-primary-db \
  --query "DBInstances[0].[StorageEncrypted,KmsKeyId]" \
  --region ap-southeast-1
```

2. Inspect the EBS volume attachments on running EC2 instances:
```
aws ec2 describe-volumes \
  --filters "Name=attachment.instance-id,Values=<INSTANCE_ID>" \
  --query "Volumes[*].[Encrypted,KmsKeyId]" \
  --region ap-southeast-1
```

- Verification Criteria:

+Both outputs return Encrypted: true.

+The KmsKeyId attribute matches the ARN of the custom KMS CMK provisioned in modules/security/kms.tf.


<br>

### Scenario 4: Automated Database Credential Rotation

- Objective: Validate that database credentials in AWS Secrets Manager rotate automatically without causing application downtime.

- Execution:

1. Trigger an immediate manual rotation test via AWS CLI:
```
SECRET_ID=$(terraform -chdir=terraform/environments/primary-singapore output -raw rds_secret_arn)
aws secretsmanager rotate-secret \
  --secret-id "$SECRET_ID" \
  --region ap-southeast-1
```

2. Inspect the secret version staging labels:
```
aws secretsmanager describe-secret \
  --secret-id "$SECRET_ID" \
  --query "VersionIdsToStages" \
  --region ap-southeast-1
```

3. Send traffic to the web application dashboard:
```
curl -s "http://$ALB_URL/" | grep -i "Database Connection Status"
```

- Verification Criteria:

+Secrets Manager shows a new version ID assigned the AWSCURRENT staging label, with the prior version moved to AWSPREVIOUS.

+The application maintains its connection pool to PostgreSQL, returning Connected to [enterprisedb] without throwing connection errors.


<br>


### Scenario 5: CIS AWS Foundations Benchmark Compliance Audit

- Objective: Verify that the infrastructure meets or exceeds enterprise compliance baselines when audited by AWS Security Hub.

- Execution:

1. Navigate to AWS Console $\rightarrow$ Security Hub $\rightarrow$ Security standards.

2. Open the CIS AWS Foundations Benchmark v1.4.0 (or v3.0) dashboard.

3. Review findings across Identity and Access Management, Storage, Logging, and Networking.

- Verification Criteria:

Overall security compliance score exceeds 85–90%.

Key controls verified:

- 1.16: Ensure IAM policies do not grant full administrative privileges.

- 2.1.1: Ensure S3 buckets block public access.

- 3.1: Ensure VPC flow logging is enabled.

- 4.1: Ensure no security groups allow ingress from 0.0.0.0/0 to port 22.

- 5.1: Ensure no Network ACLs allow ingress from 0.0.0.0/0 to remote management ports.



<br>



## 6. Challenges Encountered & Resolutions

Challenge / VulnerabilityRoot Cause AnalysisRemediationWAF False Positives on Health ProbesThe AWSManagedRulesCommonRuleSet flagged rapid Synthetic Canary health probes as an anomalous scanning tool.Added an explicit WAF rule override with higher priority that excludes the /healthz URI from token inspection.KMS Decryption Failure on Auto ScalingThe Auto Scaling service-linked role lacked permission to invoke kms:CreateGrant on the Customer Managed Key during instance launch.Updated the KMS Key Policy to grant kms:CreateGrant and kms:Decrypt to arn:aws:iam::<ACCOUNT_ID>:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling.Secrets Rotation Connection DropInitial rotation terminated active PostgreSQL connections abruptly when altering the master user password.Configured the Lambda rotation function using a two-user alternating strategy, allowing existing connections to finish before recycling credentials.

