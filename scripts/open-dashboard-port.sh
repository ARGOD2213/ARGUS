#!/bin/bash
# Run ONLY after Spring Security HTTP Basic auth is confirmed working.
# Opens port 8080 to internet so phone browser can reach dashboards.
# Auth is enforced by Spring Security - not by SG.

set -e
REGION="ap-south-1"
INSTANCE_ID="i-0761b14159f2e2a3f"

SG_ID=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

echo "Security group: $SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

echo "Port 8080 open to internet."
echo "Auth is enforced by Spring Security HTTP Basic."
echo "Dashboard URL: http://$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID --region $REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text):8080/"
