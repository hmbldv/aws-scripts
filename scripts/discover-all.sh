#!/bin/bash
# Master AWS Resource Discovery Script
# Runs all individual discovery scripts and generates comprehensive report
# Usage: ./discover-all.sh [--format json|table|human] [--account-name NAME]

set -e

# Default values
FORMAT="${1:-human}"
ACCOUNT_NAME="${2:-$(aws sts get-caller-identity --query Account --output text)}"
OUTPUT_DIR="../output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="$OUTPUT_DIR/report_${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create report directory
mkdir -p "$REPORT_DIR"

# Get AWS account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ACCOUNT_ARN=$(aws sts get-caller-identity --query Arn --output text)
REGION=$(aws configure get region || echo "us-west-1")

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AWS Resource Discovery - Master Aggregation Script      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Account ID:${NC} $ACCOUNT_ID"
echo -e "${GREEN}Account Name:${NC} $ACCOUNT_NAME"
echo -e "${GREEN}Region:${NC} $REGION"
echo -e "${GREEN}Caller ARN:${NC} $ACCOUNT_ARN"
echo -e "${GREEN}Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${GREEN}Report Directory:${NC} $REPORT_DIR"
echo ""

# Array of resource types and their scripts
declare -A SCRIPTS=(
  ["IAM Roles"]="discover-iam-roles.sh"
  ["OIDC Providers"]="discover-oidc-providers.sh"
  ["IAM Policies"]="discover-iam-policies.sh"
  ["EC2 Instances"]="discover-ec2-instances.sh"
  ["S3 Buckets"]="discover-s3-buckets.sh"
  ["VPCs"]="discover-vpcs.sh"
)

# Run each discovery script
for RESOURCE_TYPE in "${!SCRIPTS[@]}"; do
  SCRIPT="${SCRIPTS[$RESOURCE_TYPE]}"

  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Discovering: $RESOURCE_TYPE${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [ -f "./$SCRIPT" ]; then
    "./$SCRIPT" "$FORMAT" 2>&1 | tee -a "$REPORT_DIR/discovery.log"
    echo ""
  else
    echo -e "${RED}Error: Script $SCRIPT not found${NC}"
  fi
done

# Move all output files to report directory
mv "$OUTPUT_DIR"/*_${TIMESTAMP}* "$REPORT_DIR/" 2>/dev/null || true

# Generate summary report
SUMMARY_FILE="$REPORT_DIR/SUMMARY.txt"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║               Generating Summary Report                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

cat > "$SUMMARY_FILE" << EOF
AWS Resource Discovery Summary Report
======================================

Account Information
-------------------
Account ID: $ACCOUNT_ID
Account Name: $ACCOUNT_NAME
Region: $REGION
Caller Identity: $ACCOUNT_ARN
Scan Date: $(date '+%Y-%m-%d %H:%M:%S')

Resource Counts
---------------
EOF

# Count resources (best effort)
echo "IAM Roles (non-AWS): $(aws iam list-roles --output json | jq '[.Roles[] | select(.RoleName | startswith("AWS") | not)] | length')" >> "$SUMMARY_FILE"
echo "OIDC Providers: $(aws iam list-open-id-connect-providers --output json | jq '.OpenIDConnectProviderList | length')" >> "$SUMMARY_FILE"
echo "IAM Policies (Customer-Managed): $(aws iam list-policies --scope Local --output json | jq '.Policies | length')" >> "$SUMMARY_FILE"
echo "EC2 Instances: $(aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' --output json | jq 'flatten | length')" >> "$SUMMARY_FILE"
echo "S3 Buckets: $(aws s3api list-buckets --output json | jq '.Buckets | length')" >> "$SUMMARY_FILE"
echo "VPCs: $(aws ec2 describe-vpcs --output json | jq '.Vpcs | length')" >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" << EOF

Report Files
------------
All discovery data has been saved to: $REPORT_DIR

Format: $FORMAT
EOF

# Display summary
cat "$SUMMARY_FILE"

echo ""
echo -e "${GREEN}✅ Discovery Complete!${NC}"
echo -e "${GREEN}📁 Report saved to: $REPORT_DIR${NC}"
echo ""

# If human format, also create a consolidated human-readable report
if [ "$FORMAT" == "human" ]; then
  CONSOLIDATED_REPORT="$REPORT_DIR/CONSOLIDATED_REPORT.txt"

  echo -e "${BLUE}Creating consolidated human-readable report...${NC}"

  {
    cat "$SUMMARY_FILE"
    echo ""
    echo "========================================"
    echo "Detailed Resource Information"
    echo "========================================"
    echo ""

    # Concatenate all human-readable reports
    for file in "$REPORT_DIR"/*_human.txt; do
      if [ -f "$file" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$file"
      fi
    done
  } > "$CONSOLIDATED_REPORT"

  echo -e "${GREEN}📄 Consolidated report: $CONSOLIDATED_REPORT${NC}"
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Review the discovery reports in: ${GREEN}$REPORT_DIR${NC}"
echo -e "  2. Identify resources not managed by Terraform"
echo -e "  3. Use terraform import or code generation tools"
echo ""
