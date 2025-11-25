#!/bin/bash
# Discover S3 Buckets
# Usage: ./discover-s3-buckets.sh [--format json|table|human]

set -e

FORMAT="${1:-json}"
OUTPUT_DIR="../output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "🔍 Discovering S3 Buckets..."

case "$FORMAT" in
  json)
    aws s3api list-buckets --output json > "$OUTPUT_DIR/s3-buckets_${TIMESTAMP}.json"
    echo "✅ Saved to: $OUTPUT_DIR/s3-buckets_${TIMESTAMP}.json"
    ;;
  table)
    aws s3 ls | tee "$OUTPUT_DIR/s3-buckets_${TIMESTAMP}.txt"
    ;;
  human)
    echo "S3 Buckets Discovery Report"
    echo "==========================="
    echo ""

    BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output json | jq -r '.[]')

    if [ -z "$BUCKETS" ]; then
      echo "No S3 buckets found."
    else
      for BUCKET in $BUCKETS; do
        REGION=$(aws s3api get-bucket-location --bucket "$BUCKET" --output json 2>/dev/null | jq -r '.LocationConstraint // "us-east-1"')
        CREATION_DATE=$(aws s3api list-buckets --output json | jq -r ".Buckets[] | select(.Name==\"$BUCKET\") | .CreationDate")

        echo "Bucket: $BUCKET"
        echo "  Region: $REGION"
        echo "  Created: $CREATION_DATE"

        # Check versioning
        VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET" --output json 2>/dev/null | jq -r '.Status // "Disabled"')
        echo "  Versioning: $VERSIONING"

        # Check encryption
        ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET" --output json 2>/dev/null | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm // "None"')
        echo "  Encryption: $ENCRYPTION"

        # Check public access block
        PUBLIC_BLOCK=$(aws s3api get-public-access-block --bucket "$BUCKET" --output json 2>/dev/null | jq -r '.PublicAccessBlockConfiguration.BlockPublicAcls // false')
        echo "  Public Access Blocked: $PUBLIC_BLOCK"

        echo ""
      done
    fi | tee "$OUTPUT_DIR/s3-buckets_${TIMESTAMP}_human.txt"
    ;;
  *)
    echo "Error: Unknown format '$FORMAT'. Use: json, table, or human"
    exit 1
    ;;
esac
