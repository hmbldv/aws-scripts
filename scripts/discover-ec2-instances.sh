#!/bin/bash
# Discover EC2 Instances
# Usage: ./discover-ec2-instances.sh [--format json|table|human]

set -e

FORMAT="${1:-json}"
OUTPUT_DIR="../output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "🔍 Discovering EC2 Instances..."

case "$FORMAT" in
  json)
    aws ec2 describe-instances --output json > "$OUTPUT_DIR/ec2-instances_${TIMESTAMP}.json"
    echo "✅ Saved to: $OUTPUT_DIR/ec2-instances_${TIMESTAMP}.json"
    ;;
  table)
    aws ec2 describe-instances \
      --query 'Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],Type:InstanceType,State:State.Name,AZ:Placement.AvailabilityZone}' \
      --output table | tee "$OUTPUT_DIR/ec2-instances_${TIMESTAMP}.txt"
    ;;
  human)
    echo "EC2 Instances Discovery Report"
    echo "=============================="
    echo ""

    INSTANCE_IDS=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' --output json | jq -r '.[][] // empty')

    if [ -z "$INSTANCE_IDS" ]; then
      echo "No EC2 instances found."
    else
      for INSTANCE_ID in $INSTANCE_IDS; do
        INSTANCE_INFO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output json | jq -r '.Reservations[0].Instances[0]')

        NAME=$(echo "$INSTANCE_INFO" | jq -r '.Tags[]? | select(.Key=="Name") | .Value // "N/A"')
        STATE=$(echo "$INSTANCE_INFO" | jq -r '.State.Name')
        TYPE=$(echo "$INSTANCE_INFO" | jq -r '.InstanceType')
        AZ=$(echo "$INSTANCE_INFO" | jq -r '.Placement.AvailabilityZone')
        LAUNCH_TIME=$(echo "$INSTANCE_INFO" | jq -r '.LaunchTime')
        PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress // "N/A"')
        PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.PublicIpAddress // "N/A"')

        echo "Instance: $INSTANCE_ID"
        echo "  Name: $NAME"
        echo "  State: $STATE"
        echo "  Type: $TYPE"
        echo "  Availability Zone: $AZ"
        echo "  Launch Time: $LAUNCH_TIME"
        echo "  Private IP: $PRIVATE_IP"
        echo "  Public IP: $PUBLIC_IP"
        echo ""
      done
    fi | tee "$OUTPUT_DIR/ec2-instances_${TIMESTAMP}_human.txt"
    ;;
  *)
    echo "Error: Unknown format '$FORMAT'. Use: json, table, or human"
    exit 1
    ;;
esac
