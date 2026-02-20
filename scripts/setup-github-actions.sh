#!/bin/bash
# GitHub Actions Setup Script for MagicStreamMastery CI/CD
# This script helps set up AWS OIDC, GitHub Secrets, and verifies workflows

set -e

echo "================================================"
echo "  MagicStreamMastery GitHub Actions Setup"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check dependencies
echo -e "${BLUE}Checking dependencies...${NC}"
command -v git >/dev/null 2>&1 || { echo -e "${RED}git not found${NC}"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}aws cli not found${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${YELLOW}jq not found (optional)${NC}"; }

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account ID: $ACCOUNT_ID${NC}"

# Get GitHub repo info
GITHUB_REPO=$(git remote get-url origin | sed 's/.*://;s/.git//')
GITHUB_ORG=$(echo $GITHUB_REPO | cut -d'/' -f1)
GITHUB_REPO_NAME=$(echo $GITHUB_REPO | cut -d'/' -f2)
echo -e "${GREEN}✓ GitHub Repository: $GITHUB_ORG/$GITHUB_REPO_NAME${NC}"

echo ""
echo -e "${BLUE}Step 1: Create AWS IAM OIDC Provider${NC}"
echo "================================================"

# Check if OIDC provider exists
if aws iam list-open-id-connect-providers | grep -q "token.actions.githubusercontent.com"; then
  echo -e "${GREEN}✓ OIDC provider already exists${NC}"
else
  echo "Creating OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --thumbprint-list 1b511abead59c6ce207077c0ef0302405a62f5ff \
    --client-id-list sts.amazonaws.com
  echo -e "${GREEN}✓ OIDC provider created${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Create IAM Role for GitHub Actions${NC}"
echo "================================================"

ROLE_NAME="github-actions-magicstream"

# Check if role exists
if aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
  echo -e "${GREEN}✓ IAM role already exists: $ROLE_NAME${NC}"
else
  echo "Creating IAM role and trust policy..."
  
  cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_ORG/$GITHUB_REPO_NAME:*"
        }
      }
    }
  ]
}
EOF

  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --description "Role for GitHub Actions CI/CD"
  
  rm trust-policy.json
  echo -e "${GREEN}✓ IAM role created: $ROLE_NAME${NC}"
fi

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
echo -e "${GREEN}✓ Role ARN: $ROLE_ARN${NC}"

echo ""
echo -e "${BLUE}Step 3: Attach IAM Policies${NC}"
echo "================================================"

POLICIES=(
  "arn:aws:iam::aws:policy/AmazonEKSFullAccess"
  "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  "arn:aws:iam::aws:policy/IAMFullAccess"
)

for policy in "${POLICIES[@]}"; do
  POLICY_NAME=$(echo $policy | rev | cut -d'/' -f1 | rev)
  if aws iam list-attached-role-policies --role-name $ROLE_NAME | grep -q $POLICY_NAME; then
    echo -e "${GREEN}✓ $POLICY_NAME already attached${NC}"
  else
    aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $policy
    echo -e "${GREEN}✓ Attached: $POLICY_NAME${NC}"
  fi
done

echo ""
echo -e "${BLUE}Step 4: Set GitHub Secrets${NC}"
echo "================================================"

echo -e "${YELLOW}GitHub Secrets to set in your repository:${NC}"
echo ""
echo "Go to: https://github.com/$GITHUB_ORG/$GITHUB_REPO_NAME/settings/secrets/actions"
echo ""
echo "Add these secrets:"
echo ""
echo "  Name: AWS_ROLE_ARN"
echo "  Value: $ROLE_ARN"
echo ""
echo "  Name: DOCKER_USERNAME"
echo "  Value: <your Docker Hub username>"
echo ""
echo "  Name: DOCKER_PASSWORD"
echo "  Value: <your Docker Hub access token>"
echo ""

echo -e "${BLUE}Step 5: Create Terraform Variables File${NC}"
echo "================================================"

TFVARS_FILE="infrastructure/terraform/environments/dev/dev.tfvars"

if [ -f "$TFVARS_FILE" ]; then
  echo -e "${GREEN}✓ $TFVARS_FILE already exists${NC}"
else
  echo "Creating $TFVARS_FILE..."
  
  cat > "$TFVARS_FILE" << 'EOF'
# Development environment variables
# WARNING: This file contains secrets - NEVER commit to git!

db_password                  = "your-secure-db-password"
openai_api_key               = "sk-your-openai-api-key"
mongodb_uri                  = "mongodb+srv://username:password@cluster.mongodb.net/magic-stream-movies?appName=Magic-Stream"
secret_key                   = "generate-a-random-string-for-jwt-secret"
refresh_token_secret_key     = "generate-another-random-string-for-jwt-refresh"
allowed_origins              = "http://localhost:3000,http://localhost:8081"
EOF

  echo -e "${YELLOW}⚠️  Edit $TFVARS_FILE with your actual values${NC}"
  echo -e "${GREEN}✓ Template created${NC}"
fi

echo ""
echo -e "${BLUE}Step 6: Verify Repository Configuration${NC}"
echo "================================================"

# Check .gitignore
if grep -q "*.tfvars" .gitignore 2>/dev/null; then
  echo -e "${GREEN}✓ .gitignore includes *.tfvars${NC}"
else
  echo -e "${YELLOW}  Adding *.tfvars and *.tfvars.json to .gitignore${NC}"
  cat >> .gitignore << EOF

# Terraform secrets (NEVER commit)
*.tfvars
*.tfvars.json

# Terraform state (encrypted in S3 backend)
*.tfstate
*.tfstate.*
.terraform/
EOF
  git add .gitignore
  git commit -m "Add tfvars to gitignore"
fi

# Check workflows exist
WORKFLOWS=(
  ".github/workflows/build-and-push.yml"
  ".github/workflows/terraform-plan.yml"
  ".github/workflows/terraform-apply.yml"
  ".github/workflows/deploy-k8s.yml"
  ".github/workflows/security-scan.yml"
)

echo ""
for workflow in "${WORKFLOWS[@]}"; do
  if [ -f "$workflow" ]; then
    echo -e "${GREEN}✓ $workflow found${NC}"
  else
    echo -e "${RED}✗ $workflow missing${NC}"
  fi
done

echo ""
echo "================================================"
echo -e "${GREEN} Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit $TFVARS_FILE with your actual secrets"
echo "2. Add GitHub Secrets using the values above"
echo "3. Push your changes:"
echo ""
echo "  git add ."
echo "  git commit -m 'Add GitHub Actions CI/CD pipeline'"
echo "  git push origin main"
echo ""
echo "4. Check GitHub Actions:"
echo "  https://github.com/$GITHUB_ORG/$GITHUB_REPO_NAME/actions"
echo ""
echo "For more information, see: .github/CICD_README.md"
echo ""
