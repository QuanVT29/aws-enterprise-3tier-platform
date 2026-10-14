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

![](images/phase5-dr-architecture.png)

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
| **Phase A: Incident Detection** | Primary degradation detected via distributed synthetic checks | Route 53 Health Check (3 failed probes across 30s) | Health Check status shifts from `Healthy` to `Unhealthy` |
| **Phase B: Replica Promotion** | Asynchronous replication stops; replica assumes primary status | AWS CLI: `aws rds promote-read-replica` | RDS Event: Status shifts `rebooting` $\rightarrow$ `backing-up` $\rightarrow$ `available` |
| **Phase C: Compute Fleet Expansion** | Secondary ASG expands from Pilot Light to Production capacity | Auto Scaling CLI: `set-desired-capacity 2` | ASG Activity: Launching instance `i-0022dc2913fc2b85d` |
| **Phase D: Ingress Redirection** | User traffic shifts to Sydney ALB | Route 53 Failover record set switchover | Application UI renders `ap-southeast-2a` metadata |



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
  --query "DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address,ReplicationLag]" \
  --output table
```

- Verification Criteria:

+Database Identifier: prod-dr-sydney-replica.

+Database Status: available.

+Endpoint Address: prod-dr-sydney-replica.chqkyga2un9r.ap-southeast-2.rds.amazonaws.com

+Replication Lag: None / 0 seconds (well below the < 5 minutes SLA threshold).

+AWS Console Replication Topology: Confirms prod-dr-sydney-replica (Role: Replica, Region: ap-southeast-2a) is actively Replicating from prod-primary-db (Singapore).

![](images/proof-rds-cross-region-replica-1.png) 

![](images/proof-rds-cross-region-replica-2.png) 

<br>


### Scenario 2: Route 53 Health Checking & Active-Passive Policy

- Objective: Confirm that global DNS health checks monitor primary ingress health and trigger failover status correctly.

- Execution: Open AWS Console $\rightarrow$ Route 53 $\rightarrow$ Health checks and review the primary ingress health monitor.

- Verification Criteria:

+Health check state reflects Healthy with latency metrics streaming across all global health check agent locations.

+The Primary record resolves to the Singapore ALB DNS, while the Secondary record binds to the Sydney ALB DNS.

+Configuration: Request interval = 10 seconds, Failure threshold = 3

+Health Status: Healthy (100% across all 8 global checker regions).

+Global checker regions active: US East (N. Virginia), US West (N. California), US West (Oregon), Asia Pacific (Tokyo), Asia Pacific (Singapore), Asia Pacific (Sydney), EU (Ireland), South America (Sao Paulo).

![](images/proof-route53-healthcheck-1.png)

![](images/proof-route53-healthcheck-2.png)


<br>


### Scenario 3: Automated Failover Drill Execution (trigger-dr-failover.sh)

- Objective: Execute an automated regional failover drill simulating a complete collapse of AWS Region Singapore.

- Execution:

1. Trigger the automated SRE disaster recovery script from the management terminal:
```
chmod +x scripts/trigger-dr-failover.sh
./scripts/trigger-dr-failover.sh
```

2. Monitor terminal log outputs as the script severs cross-region replication, promotes the Sydney database, and scales up the secondary compute cluster.

- Verification Criteria:

+Script successfully detected the Sydney replica, initiated promotion, and handled transient database states (rebooting, backing-up) over 15-second polling cycles.

+Read Replica Promotion: Confirmed standalone read/write state achieved

+Compute Expansion: Automatically discovered target ASG prod-dr-asg-20261014162209685500000001 and scaled desired capacity to 2 instances.

+Measured Operational RTO: 5m 22s (drastically outperforming the 15-minute SLA target).

![](images/proof-dr-failover-execution.png)

<br>


### Scenario 4: Promotion of Read Replica to Standalone Primary

- Objective: Confirm that the promoted Sydney database instance dropped replica constraints and operates as an independent read/write primary engine.

- Execution: Inspect database configuration details and the replication topology table in the AWS RDS Sydney Console.

- Verification Criteria:

+Database Identifier: prod-dr-sydney-replica

+Status: Available

+Role: Formally transitioned from Replica to Instance (Primary Standalone)

+Replication Source: Transitioned from prod-primary-db to - (None), confirming complete independence from the Singapore primary instance.

+Engine: PostgreSQL on db.t4g.micro located in ap-southeast-2a

![](images/proof-replica-promotion.png)



<br>


### Scenario 5: Secondary Region Traffic Ingress & RTO/RPO Measurement

- Objective: Verify that end-user traffic routes directly into Sydney compute resources and that the application tier establishes a valid connection to the local database.

- Execution:

1. Dispatch HTTP request to the Sydney Application Load Balancer:
```
curl -i http://<FAILOVER-DOMAIN-OR-ALB>/
```

2. Inspect system diagnostics rendered on the web dashboard

   
#### Observations & Measured Result:

- Host Endpoint: prod-dr-public-alb-453913900.ap-southeast-2.elb.amazonaws.com

- Serving Availability Zone: ap-southeast-2a

- Measured RPO: < 20 seconds (Target: < 5 minutes) — ACHIEVED.

- Database Connectivity: Connected to [enterprisedb] verified at Wed Oct 14 2026 18:18:40 GMT+0000.

##### SLA Benchmark Compliance:

- Target RTO: < 15 minutes $\rightarrow$ Actual: 5 minutes 22 seconds (ACHIEVED).

- Target RPO: < 5 minutes $\rightarrow$ Actual: < 15 seconds (ACHIEVED).


![](images/proof-dr-traffic-switch.png)

<br>




### 6. Challenges Encountered & Resolutions

| Challenge / Drift Factor | Root Cause Analysis | Remediation |
| :--- | :--- | :--- |
| **KMS Cross-Region Decryption Rejection** | Sydney instances failed during boot because Auto Scaling lacked authorization to generate data keys on the local CMK. | Added `AllowAutoScalingServiceRole` and `AllowAutoScalingCreateGrant` blocks to the Sydney KMS Key Policy in `dr-sydney/main.tf`. |
| **Remote State Bucket Path Mismatch** | `dr-sydney/main.tf` attempted to load state from `environments/primary-singapore/terraform.tfstate`, which returned a 404 error. | Corrected the S3 key parameter to `primary-singapore/terraform.tfstate` matching `enterprise-tf-state-222634368199-ap-southeast-1`. |
| **ASG Scaling Capacity Timeout** | Initial ASG provisioning stalled waiting for instances to register healthy with the target group. | Resolved KMS authorization to permit instantaneous EBS volume encryption upon node launch. |
