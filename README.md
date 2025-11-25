# AWS Resource Discovery Scripts

A collection of shell scripts to discover and audit AWS resources across your accounts. These scripts help identify resources created outside Infrastructure as Code (IaC) tools like Terraform, making it easier to bring your infrastructure under version control.

## Features

- **Individual Resource Discovery**: Run targeted scans for specific AWS resource types
- **Master Aggregation Script**: Scan all resource types at once with consolidated reporting
- **Multiple Output Formats**: JSON (raw data), Table (quick view), or Human-readable (detailed)
- **Timestamped Reports**: All outputs are timestamped for audit trails
- **No Dependencies**: Uses only AWS CLI and standard Unix tools (jq, bash)

## Resource Types Supported

| Resource Type | Script | Description |
|---------------|--------|-------------|
| IAM Roles | `discover-iam-roles.sh` | Lists non-AWS managed roles with attached policies |
| OIDC Providers | `discover-oidc-providers.sh` | Discovers IAM OIDC identity providers (GitLab, GitHub, etc.) |
| IAM Policies | `discover-iam-policies.sh` | Lists customer-managed IAM policies |
| EC2 Instances | `discover-ec2-instances.sh` | Discovers EC2 instances with state and metadata |
| S3 Buckets | `discover-s3-buckets.sh` | Lists S3 buckets with encryption and versioning status |
| VPCs | `discover-vpcs.sh` | Discovers VPCs with CIDR blocks and subnet counts |

## Prerequisites

### Required Tools

- **AWS CLI v2** - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **jq** - JSON processor ([Download](https://stedolan.github.io/jq/download/))
- **bash** - Shell (comes with Linux/macOS)

Install on Ubuntu/Debian:
```bash
sudo apt update
sudo apt install awscli jq
```

Install on macOS:
```bash
brew install awscli jq
```

### AWS Credentials

Configure AWS CLI with your credentials:

```bash
# Using AWS SSO (recommended)
aws configure sso

# Or using access keys
aws configure
```

Verify your credentials:
```bash
aws sts get-caller-identity
```

### IAM Permissions Required

The scripts require read-only IAM permissions for the resources you want to discover:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:ListRoles",
        "iam:GetRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListOpenIDConnectProviders",
        "iam:GetOpenIDConnectProvider",
        "iam:ListPolicies",
        "iam:GetPolicy",
        "ec2:DescribeInstances",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeRouteTables",
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:GetBucketEncryption",
        "s3:GetPublicAccessBlock"
      ],
      "Resource": "*"
    }
  ]
}
```

## Installation

Clone the repository:

```bash
git clone https://github.com/hmbldv/aws-scripts.git
cd aws-scripts
```

Navigate to the scripts directory:

```bash
cd scripts
```

All scripts are executable and ready to run.

## Usage

### Individual Scripts

Each script can be run independently to discover a specific resource type:

```bash
# Discover IAM roles
./discover-iam-roles.sh [--format json|table|human]

# Discover OIDC providers
./discover-oidc-providers.sh [--format json|table|human]

# Discover IAM policies
./discover-iam-policies.sh [--format json|table|human]

# Discover EC2 instances
./discover-ec2-instances.sh [--format json|table|human]

# Discover S3 buckets
./discover-s3-buckets.sh [--format json|table|human]

# Discover VPCs
./discover-vpcs.sh [--format json|table|human]
```

### Master Aggregation Script

Run all discovery scripts at once:

```bash
./discover-all.sh [--format json|table|human] [--account-name NAME]
```

**Examples:**

```bash
# Human-readable format (default)
./discover-all.sh human production-account

# JSON format for programmatic parsing
./discover-all.sh json

# Table format for quick console viewing
./discover-all.sh table
```

## Output Formats

### JSON Format

Raw AWS CLI JSON output suitable for programmatic processing:

```bash
./discover-iam-roles.sh json
```

**Output:** `output/iam-roles_20251124_143022.json`

**Use case:** Parse with jq, import into databases, feed into other tools

### Table Format

AWS CLI table output for quick visual inspection:

```bash
./discover-ec2-instances.sh table
```

**Output:** Console table + `output/ec2-instances_20251124_143022.txt`

**Use case:** Quick glance at resource names and IDs

### Human-Readable Format

Detailed, formatted reports with all resource metadata:

```bash
./discover-s3-buckets.sh human
```

**Output:** `output/s3-buckets_20251124_143022_human.txt`

**Example:**
```
S3 Buckets Discovery Report
===========================

Bucket: terraform-state-266735821834-us-west-1
  Region: us-west-1
  Created: 2025-11-21T17:34:56.000Z
  Versioning: Enabled
  Encryption: AES256
  Public Access Blocked: true
```

**Use case:** Audit reports, documentation, sharing with teammates

## Report Structure

### Master Aggregation Output

When running `discover-all.sh`, a timestamped report directory is created:

```
output/
└── report_20251124_143022/
    ├── SUMMARY.txt                          # Resource counts and metadata
    ├── CONSOLIDATED_REPORT.txt              # All human-readable reports combined
    ├── discovery.log                        # Script execution log
    ├── iam-roles_20251124_143022.json       # Raw IAM roles data
    ├── iam-roles_20251124_143022_human.txt  # Human-readable IAM roles
    ├── oidc-providers_20251124_143022.json
    ├── oidc-providers_20251124_143022_human.txt
    ├── ec2-instances_20251124_143022.json
    ├── ec2-instances_20251124_143022_human.txt
    ├── s3-buckets_20251124_143022.json
    ├── s3-buckets_20251124_143022_human.txt
    ├── vpcs_20251124_143022.json
    ├── vpcs_20251124_143022_human.txt
    ├── iam-policies_20251124_143022.json
    └── iam-policies_20251124_143022_human.txt
```

### SUMMARY.txt Example

```
AWS Resource Discovery Summary Report
======================================

Account Information
-------------------
Account ID: 266735821834
Account Name: production-account
Region: us-west-1
Caller Identity: arn:aws:sts::266735821834:assumed-role/...
Scan Date: 2025-11-24 14:30:22

Resource Counts
---------------
IAM Roles (non-AWS): 12
OIDC Providers: 1
IAM Policies (Customer-Managed): 5
EC2 Instances: 4
S3 Buckets: 3
VPCs: 1
```

## Use Cases

### 1. Terraform Import Discovery

**Problem:** You have AWS resources created manually or via CloudFormation that need to be managed by Terraform.

**Solution:**
```bash
# Run discovery
./discover-all.sh human production

# Review CONSOLIDATED_REPORT.txt to identify unmanaged resources
cat output/report_*/CONSOLIDATED_REPORT.txt

# Use terraform import for each resource
terraform import aws_iam_role.devops_operator devops-operator
```

### 2. Security Audit

**Problem:** Quarterly security audit requires documentation of all IAM roles and their permissions.

**Solution:**
```bash
# Generate audit report
./discover-iam-roles.sh human
./discover-iam-policies.sh human

# Share human-readable reports with security team
```

### 3. Multi-Account Scanning

**Problem:** Your organization has multiple AWS accounts and you need to inventory resources across all of them.

**Solution:**
```bash
# Loop through AWS profiles
for PROFILE in prod staging dev; do
  export AWS_PROFILE=$PROFILE
  ./discover-all.sh human $PROFILE
done

# Compare reports across accounts
diff output/report_prod_*/SUMMARY.txt output/report_staging_*/SUMMARY.txt
```

### 4. Cost Optimization

**Problem:** Identify unused or forgotten resources that are incurring costs.

**Solution:**
```bash
# Discover EC2 instances
./discover-ec2-instances.sh human

# Review for stopped instances
grep -A 7 "State: stopped" output/*ec2-instances*_human.txt

# Discover S3 buckets and check for empty/unused ones
./discover-s3-buckets.sh human
```

## Advanced Usage

### Filtering Results with jq

Use jq to filter JSON output:

```bash
# Find only running EC2 instances
./discover-ec2-instances.sh json
cat output/ec2-instances_*.json | jq '.Reservations[].Instances[] | select(.State.Name=="running")'

# Get all IAM roles with "admin" in the name
./discover-iam-roles.sh json
cat output/iam-roles_*.json | jq '.Roles[] | select(.RoleName | contains("admin"))'

# List S3 buckets without encryption
./discover-s3-buckets.sh json
# (then parse with jq to check encryption settings)
```

### Cross-Region Discovery

The scripts use your configured AWS region by default. To scan multiple regions:

```bash
for REGION in us-west-1 us-east-1 eu-west-1; do
  export AWS_DEFAULT_REGION=$REGION
  ./discover-all.sh human "prod-$REGION"
done
```

### Automated Scheduled Scans

Set up a cron job to run daily scans:

```bash
# Edit crontab
crontab -e

# Add daily scan at 2 AM
0 2 * * * cd /home/user/aws-scripts/scripts && ./discover-all.sh human daily-scan >> /var/log/aws-discovery.log 2>&1
```

## Troubleshooting

### Error: "Token has expired and refresh failed"

**Problem:** AWS SSO session expired

**Solution:**
```bash
aws sso login
```

### Error: "An error occurred (AccessDenied)"

**Problem:** Insufficient IAM permissions

**Solution:** Ensure your IAM role/user has the required read permissions (see Prerequisites)

### Error: "jq: command not found"

**Problem:** jq is not installed

**Solution:**
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

### Empty Output

**Problem:** No resources found

**Possible causes:**
- Wrong AWS region configured
- Resources don't exist in this account
- Filters excluding all results

**Solution:**
```bash
# Verify account
aws sts get-caller-identity

# Check region
aws configure get region
```

## Project Structure

```
aws-scripts/
├── README.md                        # This file
├── scripts/                         # Discovery scripts
│   ├── discover-all.sh              # Master aggregation script
│   ├── discover-iam-roles.sh        # IAM roles discovery
│   ├── discover-oidc-providers.sh   # OIDC providers discovery
│   ├── discover-iam-policies.sh     # IAM policies discovery
│   ├── discover-ec2-instances.sh    # EC2 instances discovery
│   ├── discover-s3-buckets.sh       # S3 buckets discovery
│   └── discover-vpcs.sh             # VPCs discovery
├── output/                          # Generated reports (gitignored)
└── docs/                            # Additional documentation
```

## Contributing

Contributions are welcome! To add a new resource discovery script:

1. Follow the existing script template structure
2. Support all three output formats: json, table, human
3. Add error handling with `set -e`
4. Include timestamps in output files
5. Update this README with the new resource type
6. Test with multiple AWS accounts and regions

## Roadmap

Future enhancements planned:

- [ ] Add Lambda functions discovery
- [ ] Add RDS databases discovery
- [ ] Add DynamoDB tables discovery
- [ ] Add CloudFormation stacks discovery
- [ ] Add Security Groups discovery
- [ ] Export to CSV format
- [ ] Web UI for report visualization
- [ ] Terraform code generation from discovered resources
- [ ] Drift detection (compare discovered vs. Terraform state)
- [ ] Email/Slack notifications for scheduled scans

## License

MIT License - Free to use and modify

## Credits

**Author:** hmbldv
**Purpose:** DevSecOps resource discovery and IaC migration
**Repository:** https://github.com/hmbldv/aws-scripts

## Related Projects

- [Terraformer](https://github.com/GoogleCloudPlatform/terraformer) - Generate Terraform files from existing infrastructure
- [Former2](https://former2.com/) - Web-based tool to generate IaC from AWS resources
- [aws-nuke](https://github.com/rebuy-de/aws-nuke) - Delete all resources in an AWS account
- [CloudMapper](https://github.com/duo-labs/cloudmapper) - AWS environment visualization

---

**Built with:** ❤️ and bash
**Last Updated:** 2025-11-24
