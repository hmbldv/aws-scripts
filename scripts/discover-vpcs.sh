#!/bin/bash
# Discover VPCs
# Usage: ./discover-vpcs.sh [--format json|table|human]

set -e

FORMAT="${1:-json}"
OUTPUT_DIR="../output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "🔍 Discovering VPCs..."

case "$FORMAT" in
  json)
    aws ec2 describe-vpcs --output json > "$OUTPUT_DIR/vpcs_${TIMESTAMP}.json"
    echo "✅ Saved to: $OUTPUT_DIR/vpcs_${TIMESTAMP}.json"
    ;;
  table)
    aws ec2 describe-vpcs \
      --query 'Vpcs[*].{VpcId:VpcId,CIDR:CidrBlock,IsDefault:IsDefault,Name:Tags[?Key==`Name`].Value|[0]}' \
      --output table | tee "$OUTPUT_DIR/vpcs_${TIMESTAMP}.txt"
    ;;
  human)
    echo "VPCs Discovery Report"
    echo "===================="
    echo ""

    VPC_IDS=$(aws ec2 describe-vpcs --query 'Vpcs[].VpcId' --output json | jq -r '.[]')

    if [ -z "$VPC_IDS" ]; then
      echo "No VPCs found."
    else
      for VPC_ID in $VPC_IDS; do
        VPC_INFO=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --output json | jq -r '.Vpcs[0]')

        NAME=$(echo "$VPC_INFO" | jq -r '.Tags[]? | select(.Key=="Name") | .Value // "N/A"')
        CIDR=$(echo "$VPC_INFO" | jq -r '.CidrBlock')
        IS_DEFAULT=$(echo "$VPC_INFO" | jq -r '.IsDefault')
        STATE=$(echo "$VPC_INFO" | jq -r '.State')

        echo "VPC: $VPC_ID"
        echo "  Name: $NAME"
        echo "  CIDR Block: $CIDR"
        echo "  Is Default: $IS_DEFAULT"
        echo "  State: $STATE"

        # Count subnets
        SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets | length(@)' --output text)
        echo "  Subnets: $SUBNET_COUNT"

        # List route tables
        ROUTE_TABLE_COUNT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables | length(@)' --output text)
        echo "  Route Tables: $ROUTE_TABLE_COUNT"

        echo ""
      done
    fi | tee "$OUTPUT_DIR/vpcs_${TIMESTAMP}_human.txt"
    ;;
  *)
    echo "Error: Unknown format '$FORMAT'. Use: json, table, or human"
    exit 1
    ;;
esac
