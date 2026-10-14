# Disaster Recovery Simulation & Post-Drill Audit Report

## 1. Executive Summary & Drill Objectives

This audit document certifies the execution and technical verification of the Multi-Region Disaster Recovery (BCDR) simulation. The drill evaluated the platform's capability to withstand a catastrophic outage of the primary cloud region (`ap-southeast-1` Singapore) and automatically recover critical business services in the secondary pilot light region (`ap-southeast-2` Sydney).

- **Drill Date & Time:** October 14, 2026 — 15:30 UTC+7.
- **Simulated Scenario:** Complete regional black hole of Singapore network and compute tiers.
- **Failover Mode:** Automated SRE runbook execution via `scripts/trigger-dr-failover.sh`.
- **Target SLA Thresholds:**
  - Target RTO: **< 15 minutes**
  - Target RPO: **< 5 minutes**

---

## 2. Quantitative SLA Achievement Matrix

| Metric | Target SLA | Measured Result | Compliance Status |
| :--- | :--- | :--- | :--- |
| **Recovery Time Objective (RTO)** | < 15 minutes | **7 minutes 45 seconds** | **EXCEEDED (PASSED)** |
| **Recovery Point Objective (RPO)** | < 5 minutes | **< 15 seconds** | **EXCEEDED (PASSED)** |
| **Database Transaction Loss** | 0% committed data | **0 transactions lost** | **PERFECT INTEGRITY** |
| **Secondary ASG Expansion Time** | < 5 minutes | **2 minutes 10 seconds** | **PASSED** |

---

## 3. Step-by-Step Chronological Execution Log

| Timestamp | Phase | Execution Event | Verified Output / State |
| :--- | :--- | :--- | :--- |
| **T+00:00** | Detection | Injected simulated network failure on Singapore ALB | Route 53 Health Check reported 3 failed probes |
| **T+00:35** | Trigger | Initiated failover runbook `./scripts/trigger-dr-failover.sh` | SRE operator validated Sydney replica availability |
| **T+01:10** | Database | AWS API executed `rds:PromoteReadReplica` on Sydney replica | Status shifted: `modifying` $\rightarrow$ `available` |
| **T+04:30** | Database | PostgreSQL standalone promotion finalized | DB ready for read/write workloads (`COMMIT` ok) |
| **T+05:00** | Compute | Scaled Sydney ASG from pilot light (1) to active (2 nodes) | EC2 nodes passed internal `/healthz` tests |
| **T+07:45** | Traffic | Secondary ALB actively serving global traffic | Ingress HTTP 200 responses verified from Sydney |

---

## 4. Architectural Verification Checkpoints

1. **Cryptographic Integrity:** The promoted Sydney database continued operating seamlessly using the Sydney Customer Managed Key (`alias/prod-dr-cmk`), proving regional cryptographic independence.
2. **Network Isolation:** Traffic in Sydney remained isolated within the `10.1.0.0/16` VPC, proving no dependencies on Singapore route tables.
3. **Data Loss Audit:** Comparing table sequence IDs between the last primary transaction in Singapore and the first write in Sydney verified that transactional delta was negligible (< 15 seconds of WAL replication).
