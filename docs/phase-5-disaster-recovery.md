# Phase 5: Multi-Region Disaster Recovery & Automated Failover

## 1. Architectural Scope & Objectives

The primary objective of Phase 5 is to establish enterprise-grade **Business Continuity and Disaster Recovery (BCDR)** capabilities by extending the resilient single-region foundation into a **Multi-Region Active-Passive (Warm Standby / Pilot Light)** topology. This architecture guarantees service survival against catastrophic regional outages affecting AWS Region Singapore (`ap-southeast-1`), with automated cross-region traffic redirection to AWS Region Sydney (`ap-southeast-2`).

Key resilience metrics targeted:
- **Recovery Point Objective (RPO):** **< 5 minutes** (maximum acceptable transactional data loss measured via RDS asynchronous replication latency).
- **Recovery Time Objective (RTO):** **< 15 minutes** (maximum elapsed time from regional outage detection to full operational restoration in Sydney).
- **Global Ingress Traffic Routing:** Amazon Route 53 DNS Failover with automated application health probing.
- **Cross-Region Asynchronous Data Replication:** PostgreSQL streaming physical replication between the Singapore primary instance and a Sydney cross-region read replica.
- **Infrastructure Parity as Code:** Automated provisioning of compute, networking, and security topologies in the secondary region via modularized Terraform.

```text
                                [ Global Users ]
                                       │
                                       ▼
                       [ Route 53 Failover Routing ]
                                       │
            ┌──────────────────────────┴──────────────────────────┐
   (Primary: 100% Traffic)                                (Failover Target: Warm Standby)
            ▼                                                     ▼
┌───────────────────────────────┐                     ┌───────────────────────────────┐
│     REGION AP-SOUTHEAST-1     │                     │     REGION AP-SOUTHEAST-2     │
│          (SINGAPORE)          │                     │           (SYDNEY)            │
│                               │                     │                               │
│  [ Public ALB + AWS WAF v2 ]  │                     │  [ Public ALB + AWS WAF v2 ]  │
│               │               │                     │               │               │
│               ▼               │                     │               ▼               │
│     [ EC2 ASG Cluster ]       │                     │     [ EC2 ASG Pilot Light ]   │
│         (Min: 2, Max: 4)      │                     │         (Min: 1, Max: 4)      │
│               │               │                     │               │               │
│               ▼               │                     │               ▼               │
│      [ RDS Multi-AZ DB ]      │──(Cross-Region)────>│     [ RDS Read Replica ]      │
│           (Primary)           │   Replication       │     (Promoted on Failover)    │
└───────────────────────────────┘                     └───────────────────────────────┘
```



<br>


## 2. Disaster Recovery Strategy & Technical Specifications

### 2.1 Multi-Region Resilience Tiering

- Primary Region: ap-southeast-1 (Singapore) — Full production capacity handling 100% of global ingress traffic.

- Disaster Recovery Region: ap-southeast-2 (Sydney) — Provisioned in a Warm Standby posture:

+Network (VPC, Subnets, Route Tables, Security Groups) fully pre-provisioned to mirror primary specifications.

+Compute (EC2 Auto Scaling Group) maintains a minimal baseline pilot light footprint (min_size = 1, desired_capacity = 1) to preserve compute capacity and verify health continuously.

+Database operates as a managed, synchronized Cross-Region Read Replica.


### 2.2 Global Traffic Steering (Amazon Route 53)

- Routing Policy: Active-Passive Failover Routing Policy mapped to an apex or subdomain record.

- Primary Record: Evaluates Target Health via an Amazon Route 53 Health Check monitoring http://<SINGAPORE-ALB-DNS>/healthz.

- Secondary Record: Points to <SYDNEY-ALB-DNS> and engages automatically when the primary health check enters an unhealthy state for 3 consecutive 10-second intervals.



### 2.3 Cross-Region Cryptographic Governance

- Storage encryption at rest across regions cannot share single-region KMS keys.

- Key Strategy: Dedicated Customer Managed Key (CMK) provisioned in Sydney (ap-southeast-2), granting the RDS replication service authorization to re-encrypt transactional write-ahead logs (WAL) across regional boundaries using envelope encryption (AES-256).



### 2.4 Compute Elasticity & Promotion Mechanics

- Upon regional failover invocation:

1. Asynchronous replication is severed, and the Sydney Read Replica is promoted to a standalone primary read/write database via rds:PromoteReadReplica.

2. The Sydney Auto Scaling Group scales capacity from pilot light (1 instance) to full production scale (desired_capacity = 2 or 4).

3. Route 53 shifts global DNS resolutions to Sydney's ALB endpoint.


<br>


## 3. Disaster Recovery Directory Layout

```
aws-enterprise-3tier-platform/
├── terraform/
│   ├── modules/
│   │   └── disaster-recovery/
│   │       ├── main.tf                 # Route 53 Failover Records & Health Checks
│   │       ├── rds_replica.tf          # Cross-Region RDS PostgreSQL Read Replica
│   │       ├── variables.tf            # Cross-region parameters
│   │       └── outputs.tf              # Secondary DB endpoint, Failover Domain
│   │
│   └── environments/
│       ├── primary-singapore/
│       │   ├── main.tf                 # Exports primary state & outputs
│       │   └── outputs.tf              # alb_dns_name, db_instance_id, kms_cmk_arn
│       │
│       └── dr-sydney/
│           ├── backend.tf              # S3 Backend for Sydney environment state
│           ├── main.tf                 # Multi-region orchestrator (VPC, ASG, Replica)
│           ├── variables.tf
│           ├── terraform.tfvars
│           └── outputs.tf              # dr_alb_dns_name, promoted_rds_endpoint
│
├── scripts/
│   └── trigger-dr-failover.sh          # SRE automated failover execution script
│
├── docs/
│   ├── images/
│   │   ├── phase5-dr-architecture.png
│   │   ├── proof-rds-cross-region-replica.png
│   │   ├── proof-route53-healthcheck.png
│   │   ├── proof-dr-failover-execution.png
│   │   └── proof-dr-traffic-switch.png
│   └── dr-drill-report.md              # Post-drill audit & SLA compliance verification
```


<br>


## 4. Operational Failover & Recovery Lifecycle

- The end-to-end disaster recovery execution progresses through four automated stages:


| Stage | Action | Execution Mechanism | Telemetry / Audit Trail |
| :--- | :--- | :--- | :--- |
| **Phase A: Incident Detection** | Regional degradation detected via synthetic health checks | Route 53 Health Check (3 failed probes across 30s) | Route 53 Alarm transitions to Unhealthy |
| **Phase B: Replica Promotion** | Asynchronous replication stops; replica assumes primary status | AWS CLI: `aws rds promote-read-replica` | RDS Event: Read replica promoted to standalone instance |
| **Phase C: Compute Fleet Scale-Out** | Secondary ASG expands from Pilot Light to Production capacity | Auto Scaling CLI / Terraform dynamic target scaling | ASG Activity: Launching new EC2 instances to meet target capacity |
| **Phase D: Ingress Redirection** | DNS resolutions switch worldwide to Sydney ALB | Route 53 automated health check failover switchover | Public DNS queries resolve to Sydney ALB IPv4 pool |




<br>


## 5. Verification & Testing Scenarios

### Scenario 1: Cross-Region RDS Physical Replication & Lag Monitoring

- Objective: Verify that relational database updates committed in Singapore replicate asynchronously to Sydney with minimal replication lag.

- Execution:

1. Execute transactional writes against the primary PostgreSQL database in Singapore.

2. Inspect the cross-region replication status using the AWS CLI:
```
aws rds describe-db-instances \
  --db-instance-identifier prod-dr-sydney-replica \
  --region ap-southeast-2 \
  --query "DBInstances[0].[DBInstanceIdentifier,Status,ReplicationLag]" \
  --output table
```

- Verification Criteria:

+Status indicates available.

+ReplicationLag registers 0 seconds (well within the RPO < 5 minutes threshold).


<br>


### Scenario 2: Route 53 Health Checking & Active-Passive Policy

- Objective: Confirm that global DNS health checks monitor primary ingress health and trigger failover status correctly.

- Execution: Open AWS Console $\rightarrow$ Route 53 $\rightarrow$ Health checks and review the primary ingress health monitor.

- Verification Criteria:

+Health check state reflects Healthy with latency metrics streaming across all global health check agent locations.

+The Primary record resolves to the Singapore ALB DNS, while the Secondary record binds to the Sydney ALB DNS.


<br>


### Scenario 3: Automated Failover Drill Execution (trigger-dr-failover.sh)

- Objective: Execute an automated regional failover drill simulating a complete collapse of AWS Region Singapore.

- Execution:

1. Trigger the automated SRE disaster recovery script from the management terminal:
```
./scripts/trigger-dr-failover.sh --target-region ap-southeast-2 --execute
```

2. Monitor terminal log outputs as the script severs cross-region replication, promotes the Sydney database, and scales up the secondary compute cluster.

- Verification Criteria:

+Script completes all steps with exit code 0.

+Step logs confirm successful promotion of prod-dr-sydney-replica to a primary standalone read/write database within 180 seconds.


<br>


### Scenario 4: Promotion of Read Replica to Standalone Primary

- Objective: Confirm the promoted Sydney database instance accepts write transactions independently without dependencies on Singapore.

- Execution: Connect to the promoted Sydney RDS instance via internal SSM session and execute table insertions.

- Verification Criteria:

+Database status transitions to available.

+Transaction writes (INSERT INTO diagnostics ...) succeed with COMMIT.


<br>


### Scenario 5: Secondary Region Traffic Ingress & RTO/RPO Measurement

- Objective: Measure actual system downtime and data loss metrics against targeted business continuity SLAs.

- Execution:

1. Query the global application endpoint during and after failover execution:
```
curl -i http://<FAILOVER-DOMAIN-OR-ALB>/
```

2. Inspect the Availability Zone and Deployment Region metadata rendered on the diagnostic web interface.

- Observations & Measured Result:

+Traffic routes seamlessly into ap-southeast-2 (Availability Zones: ap-southeast-2a / ap-southeast-2b).

+Measured RTO: 7 minutes 45 seconds (Target: < 15 minutes) — ACHIEVED.

+Measured RPO: < 20 seconds (Target: < 5 minutes) — ACHIEVED.




<br>




## 6. Challenges Encountered & Resolutions

Challenge / Drift FactorRoot Cause AnalysisRemediationKMS Cross-Region Decryption RejectionRDS Read Replica in Sydney failed to start because it could not decrypt transactional logs encrypted with the Singapore CMK.Provisioned a dedicated KMS CMK in ap-southeast-2 and supplied kms_key_id directly in the replica resource block.Route 53 DNS Cache LatencyLocal client DNS resolvers cached primary IP addresses beyond the expected failover window.Reduced DNS TTL on the Route 53 Failover record sets from 300 seconds to 60 seconds.Connection Pooling Timeouts During DB PromotionWeb applications threw transient connection errors during the 60-second promotion transition window.Implemented retry and exponential backoff connection logic in server.js database pool initialization.
