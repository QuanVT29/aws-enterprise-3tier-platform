#!/usr/bin/env bash
# Script: trigger-dr-failover.sh
# Description: Automates BCDR Regional Failover by promoting the Sydney RDS replica to a standalone primary and scaling out compute capacity.

set -euo pipefail

PRIMARY_REGION="ap-southeast-1"
DR_REGION="ap-southeast-2"
REPLICA_ID="prod-dr-sydney-replica"
DR_ASG_NAME="" # Tự động tìm kiếm qua AWS CLI
START_TIME=$(date +%s)

echo "======================================================================"
echo "    CRITICAL: INITIATING MULTI-REGION DISASTER RECOVERY DRILL        "
echo "======================================================================"
echo "Primary Outage Simulation: Region $PRIMARY_REGION (Singapore)"
echo "Failover Target:          Region $DR_REGION (Sydney)"
echo "Target Replica DB:        $REPLICA_ID"
echo "Timestamp:                $(date -u)"
echo "======================================================================"

# 1. KIỂM TRA TRẠNG THÁI HIỆN TẠI CỦA RDS READ REPLICA 
echo "[Step 1/3] Validating Sydney Read Replica synchronization status..."
CURRENT_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$REPLICA_ID" \
  --region "$DR_REGION" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text)

echo "--> Current Sydney Replica Status: $CURRENT_STATUS"

if [ "$CURRENT_STATUS" != "available" ]; then
  echo "[FATAL ERROR] Replica is not in 'available' state. Current: $CURRENT_STATUS. Aborting."
  exit 1
fi



# 2. PROMOTE READ REPLICA THÀNH STANDALONE PRIMARY DATABASE 
echo "[Step 2/3] Promoting Read Replica to Standalone Master Database..."
aws rds promote-read-replica \
  --db-instance-identifier "$REPLICA_ID" \
  --region "$DR_REGION" > /dev/null

echo "--> Promotion command issued. Awaiting database readiness..."

while true; do
  STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$REPLICA_ID" \
    --region "$DR_REGION" \
    --query "DBInstances[0].DBInstanceStatus" \
    --output text)
  
  if [ "$STATUS" == "available" ]; then
    echo "--> [SUCCESS] Database is now standalone and accepting write transactions!"
    break
  fi
  
  echo "--> Database status: $STATUS. Waiting 15 seconds..."
  sleep 15
done


# 3. SCALE OUT CỤM TÍNH TOÁN EC2 ASG TẠI SYDNEY TỪ PILOT LIGHT LÊN PRODUCTION 
echo "[Step 3/3] Expanding Sydney ASG compute capacity from Pilot Light to Production..."

DR_ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --region "$DR_REGION" \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'prod-dr-asg')].AutoScalingGroupName | [0]" \
  --output text)

if [ "$DR_ASG_NAME" == "None" ] || [ -z "$DR_ASG_NAME" ]; then
  echo "[WARNING] Could not auto-detect ASG name. Attempting generic search..."
  DR_ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
    --region "$DR_REGION" \
    --query "AutoScalingGroups[0].AutoScalingGroupName" \
    --output text)
fi

echo "--> Target ASG identified: $DR_ASG_NAME"
echo "--> Scaling desired capacity to 2 instances..."

aws autoscaling set-desired-capacity \
  --auto-scaling-group-name "$DR_ASG_NAME" \
  --desired-capacity 2 \
  --region "$DR_REGION"

END_TIME=$(date +%s)
TOTAL_RTO=$((END_TIME - START_TIME))
RTO_MIN=$((TOTAL_RTO / 60))
RTO_SEC=$((TOTAL_RTO % 60))

echo "    DISASTER RECOVERY FAILOVER COMPLETED SUCCESSFULLY!                "
echo "--> Operational Recovery Time (RTO): ${RTO_MIN}m ${RTO_SEC}s"
echo "--> Database Status:                 ACTIVE (Read/Write)"
echo "--> Target Traffic Region:           $DR_REGION (Sydney)"
