#!/bin/bash
# Discover IAM OIDC Providers
# Usage: ./discover-oidc-providers.sh [--format json|table|human]

set -e

FORMAT="${1:-json}"
OUTPUT_DIR="../output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "🔍 Discovering OIDC Providers..."

case "$FORMAT" in
  json)
    aws iam list-open-id-connect-providers --output json > "$OUTPUT_DIR/oidc-providers_${TIMESTAMP}.json"
    echo "✅ Saved to: $OUTPUT_DIR/oidc-providers_${TIMESTAMP}.json"
    ;;
  table)
    aws iam list-open-id-connect-providers --output table | tee "$OUTPUT_DIR/oidc-providers_${TIMESTAMP}.txt"
    ;;
  human)
    echo "OIDC Providers Discovery Report"
    echo "==============================="
    echo ""

    PROVIDER_ARNS=$(aws iam list-open-id-connect-providers --output json | jq -r '.OpenIDConnectProviderList[].Arn')

    if [ -z "$PROVIDER_ARNS" ]; then
      echo "No OIDC providers found."
    else
      for ARN in $PROVIDER_ARNS; do
        echo "OIDC Provider: $ARN"

        PROVIDER_INFO=$(aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$ARN" --output json)
        echo "  URL: $(echo "$PROVIDER_INFO" | jq -r '.Url')"
        echo "  Client IDs:"
        echo "$PROVIDER_INFO" | jq -r '.ClientIDList[]' | sed 's/^/    - /'
        echo "  Thumbprints:"
        echo "$PROVIDER_INFO" | jq -r '.ThumbprintList[]' | sed 's/^/    - /'
        echo "  Created: $(echo "$PROVIDER_INFO" | jq -r '.CreateDate')"
        echo ""
      done
    fi | tee "$OUTPUT_DIR/oidc-providers_${TIMESTAMP}_human.txt"
    ;;
  *)
    echo "Error: Unknown format '$FORMAT'. Use: json, table, or human"
    exit 1
    ;;
esac
