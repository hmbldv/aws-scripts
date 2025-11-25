#!/bin/bash
# Discover IAM Roles (excluding AWS-managed roles)
# Usage: ./discover-iam-roles.sh [--format json|table|human]

set -e

FORMAT="${1:-json}"
OUTPUT_DIR="../output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "🔍 Discovering IAM Roles..."

case "$FORMAT" in
  json)
    aws iam list-roles --output json > "$OUTPUT_DIR/iam-roles_${TIMESTAMP}.json"
    echo "✅ Saved to: $OUTPUT_DIR/iam-roles_${TIMESTAMP}.json"
    ;;
  table)
    aws iam list-roles --query 'Roles[*].{Name:RoleName,Path:Path,Created:CreateDate}' --output table | tee "$OUTPUT_DIR/iam-roles_${TIMESTAMP}.txt"
    ;;
  human)
    echo "IAM Roles Discovery Report"
    echo "=========================="
    echo ""

    # Get non-AWS managed roles
    ROLES=$(aws iam list-roles --output json | jq -r '.Roles[] | select(.RoleName | startswith("AWS") | not) | .RoleName')

    for ROLE in $ROLES; do
      echo "Role: $ROLE"

      # Get role details
      ROLE_INFO=$(aws iam get-role --role-name "$ROLE" --output json)
      echo "  Path: $(echo "$ROLE_INFO" | jq -r '.Role.Path')"
      echo "  Created: $(echo "$ROLE_INFO" | jq -r '.Role.CreateDate')"
      echo "  Description: $(echo "$ROLE_INFO" | jq -r '.Role.Description // "N/A"')"

      # Get attached policies
      echo "  Attached Policies:"
      aws iam list-attached-role-policies --role-name "$ROLE" --output json | jq -r '.AttachedPolicies[].PolicyName' | sed 's/^/    - /'

      echo ""
    done | tee "$OUTPUT_DIR/iam-roles_${TIMESTAMP}_human.txt"
    ;;
  *)
    echo "Error: Unknown format '$FORMAT'. Use: json, table, or human"
    exit 1
    ;;
esac
