#!/usr/bin/env bash
set -euo pipefail

# Usage: ./launch_spot.sh <region> <instance-name>
# Example: ./launch_spot.sh us-east-2 awsmo-spot-interrupt-kunal-1

if [ $# -lt 2 ]; then
  echo "Usage: $0 <region> <instance-name>"
  exit 1
fi

REGION="$1"
INSTANCE_NAME="$2"
PROFILE="${PROFILE:-awsmo-cust}"   # default profile, override with PROFILE env var
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"  # default instance type

echo "[INFO] Launching Spot instance in region: $REGION with name: $INSTANCE_NAME"

# Fetch the latest Amazon Linux 2 AMI ID from SSM
AMI_ID=$(aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Parameters[0].Value' \
  --output text)

echo "[INFO] Using AMI: $AMI_ID"

# Run the Spot instance
aws ec2 run-instances \
  --region "$REGION" \
  --profile "$PROFILE" \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --instance-market-options '{"MarketType":"spot"}' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query 'Instances[0].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],AZ:Placement.AvailabilityZone,State:State.Name,LaunchTime:LaunchTime}' \
  --output table | cat
