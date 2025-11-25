#!/bin/bash
# Discover IAM Policies (customer-managed only)
# Usage: ./discover-iam-policies.sh [--format json|table|human]

set -e

FORMAT="${1:-json}"
OUTPUT_DIR="../output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "🔍 Discovering IAM Policies (Customer-Managed)..."

case "$FORMAT" in
  json)
    aws iam list-policies --scope Local --output json > "$OUTPUT_DIR/iam-policies_${TIMESTAMP}.json"
    echo "✅ Saved to: $OUTPUT_DIR/iam-policies_${TIMESTAMP}.json"
    ;;
  table)
    aws iam list-policies --scope Local \
      --query 'Policies[*].{Name:PolicyName,Arn:Arn,Attachments:AttachmentCount}' \
      --output table | tee "$OUTPUT_DIR/iam-policies_${TIMESTAMP}.txt"
    ;;
  human)
    echo "IAM Policies Discovery Report (Customer-Managed)"
    echo "================================================"
    echo ""

    POLICY_ARNS=$(aws iam list-policies --scope Local --output json | jq -r '.Policies[].Arn')

    if [ -z "$POLICY_ARNS" ]; then
      echo "No customer-managed policies found."
    else
      for POLICY_ARN in $POLICY_ARNS; do
        POLICY_INFO=$(aws iam get-policy --policy-arn "$POLICY_ARN" --output json | jq -r '.Policy')

        NAME=$(echo "$POLICY_INFO" | jq -r '.PolicyName')
        DESCRIPTION=$(echo "$POLICY_INFO" | jq -r '.Description // "N/A"')
        CREATED=$(echo "$POLICY_INFO" | jq -r '.CreateDate')
        UPDATED=$(echo "$POLICY_INFO" | jq -r '.UpdateDate')
        ATTACHMENTS=$(echo "$POLICY_INFO" | jq -r '.AttachmentCount')

        echo "Policy: $NAME"
        echo "  ARN: $POLICY_ARN"
        echo "  Description: $DESCRIPTION"
        echo "  Created: $CREATED"
        echo "  Last Updated: $UPDATED"
        echo "  Attachment Count: $ATTACHMENTS"
        echo ""
      done
    fi | tee "$OUTPUT_DIR/iam-policies_${TIMESTAMP}_human.txt"
    ;;
  *)
    echo "Error: Unknown format '$FORMAT'. Use: json, table, or human"
    exit 1
    ;;
esac
