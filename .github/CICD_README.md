# CI/CD Pipeline Documentation

This document describes the GitHub Actions CI/CD pipeline for MagicStreamMastery, which automates building, testing, and deploying the full-stack application and infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflows                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Code Push to Main/Develop                                  │
│     └─→ build-and-push.yml (Build Docker images)               │
│         └─→ docker.io (nate247/magic-stream-*:*)               │
│                                                                 │
│  2. Pull Request to Main                                       │
│     └─→ terraform-plan.yml (Validate + Plan infrastructure)    │
│     └─→ security-scan.yml (Scan code + infrastructure)         │
│                                                                 │
│  3. Merge to Main                                              │
│     ├─→ build-and-push.yml (Build Docker images)               │
│     ├─→ terraform-apply.yml (Apply infrastructure + K8s)       │
│     └─→ deploy-k8s.yml (Deploy applications)                   │
│                                                                 │
│  4. Scheduled (Daily 2 AM UTC)                                 │
│     └─→ security-scan.yml (Daily vulnerability scan)           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Workflows

### 1. **build-and-push.yml** — Build Docker Images

**Triggers:** Push to `main` or `develop`, changes to `Client/`, `Server/`, or workflow file

**What it does:**

- Builds Docker images for client and server
- Pushes to Docker Hub (nate247 namespace)
- Tags images with:
  - Branch name (`main`, `develop`)
  - Git SHA (`sha-abc123`)
  - `latest` (only for `main` branch)

**Requires (GitHub Secrets):**

- `DOCKER_USERNAME` — Docker Hub username
- `DOCKER_PASSWORD` — Docker Hub access token

**Output:**

- Docker images pushed to registry
- Cache stored for faster rebuilds

---

### 2. **terraform-plan.yml** — Infrastructure Planning

**Triggers:** Pull Request to `main`, changes to `infrastructure/terraform/`

**What it does:**

- Plans infrastructure changes for `dev` and `staging`
- Validates Terraform syntax
- Checks code formatting
- Scans for security issues with Trivy and tfsec
- Posts plan summary to PR comments
- Uploads plan artifacts (for review)

**Requires (GitHub Secrets):**

- `AWS_ROLE_ARN` — IAM role for OIDC authentication

**Output:**

- Plan summary in PR comments
- Security scan results in GitHub Security tab
- Plan artifact (tfplan files)

---

### 3. **terraform-apply.yml** — Deploy Infrastructure

**Triggers:** Push to `main`, or manual workflow dispatch

**What it does:**

- Applies Terraform changes to AWS (VPC, EKS, RDS, S3)
- Updates kubeconfig for EKS cluster
- Deploys applications to Kubernetes
- Exports Terraform outputs
- Updates GitHub with deployment status

**Requires (GitHub Secrets):**

- `AWS_ROLE_ARN` — IAM role for OIDC authentication

**Environments:**

- **dev** — Auto-deployed on push to main
- **staging** and **prod** — Manual workflow dispatch

**Output:**

- Infrastructure provisioned on AWS
- Applications deployed to K8s
- Terraform outputs saved as artifacts

---

### 4. **deploy-k8s.yml** — Kubernetes Deployment

**Triggers:** Completion of `build-and-push.yml` workflow

**What it does:**

- Waits for Docker images to be built and pushed
- Updates kubeconfig
- Applies Kubernetes manifests (ConfigMaps, Secrets, Deployments, Services)
- Waits for rollouts to complete
- Runs smoke tests (/hello, /movies endpoints)
- Verifies pod health and service connectivity
- Generates deployment summary

**Requires (GitHub Secrets):**

- `AWS_ROLE_ARN` — IAM role for OIDC authentication

**Output:**

- Applications running in Kubernetes
- Deployment summary artifact
- Health verification logs

---

### 5. **security-scan.yml** — Security Scanning

**Triggers:** Push to `main`/`develop`, PR, or daily schedule (2 AM UTC)

**What it does:**

- Scans Docker images for vulnerabilities (Trivy)
- Analyzes Go server code (gosec)
- Analyzes JavaScript client code (ESLint, npm audit)
- Scans Terraform for security issues (Trivy, tfsec)
- Scans Kubernetes manifests (Kubesec, Kube-Bench)

**Requires:** None (uses container images)

**Output:**

- SARIF files uploaded to GitHub Security tab
- Vulnerabilities shown in Security tab
- Workflow summary with scan report

---

## Setup Instructions

### 1. Create AWS IAM Role for OIDC

```bash
# Create trust policy
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:GITHUB_ORG/MagicStreamMastery:*"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name github-actions-magicstream \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name github-actions-magicstream \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSFullAccess

aws iam attach-role-policy \
  --role-name github-actions-magicstream \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-role-policy \
  --role-name github-actions-magicstream \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

aws iam attach-role-policy \
  --role-name github-actions-magicstream \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
  --role-name github-actions-magicstream \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

### 2. Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions**:

```
AWS_ROLE_ARN = arn:aws:iam::ACCOUNT_ID:role/github-actions-magicstream
DOCKER_USERNAME = your-docker-hub-username
DOCKER_PASSWORD = your-docker-hub-token  (Generate at hub.docker.com/settings/security)
```

### 3. Create Terraform Variables File

Create `infrastructure/terraform/environments/dev/dev.tfvars`:

```hcl
db_password                  = "your-secure-password"
openai_api_key               = "sk-proj-..."
mongodb_uri                  = "mongodb+srv://..."
secret_key                   = "your-jwt-secret"
refresh_token_secret_key     = "your-jwt-refresh-secret"
allowed_origins              = "http://localhost:3000"
```

**  Important:** Add to `.gitignore`:

```
*.tfvars
*.tfvars.json
```

### 4. Verify Workflows

Push to your repository to trigger workflows:

```bash
git add .github/workflows/
git commit -m "Add CI/CD pipelines"
git push origin main
```

Check workflow status in **Actions** tab.

---

## Usage

### Scenario 1: Regular Development

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes to code
vim Client/magic-stream-client/src/App.jsx
vim Server/MagicStreamServer/routes/protectedRoutes.go

# Commit and push
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# Create PR
# → terraform-plan.yml (validates infrastructure code)
# → security-scan.yml (scans code + infrastructure)
# Approve PR
# → build-and-push.yml (builds Docker images)
# → terraform-apply.yml (deploys infrastructure)
# → deploy-k8s.yml (deploys applications)
```

### Scenario 2: Terraform-Only Changes

```bash
git checkout -b infra/update-eks

# Modify infrastructure
vim infrastructure/terraform/environments/dev/main.tf

git add infrastructure/terraform/
git commit -m "Scale EKS cluster"
git push origin infra/update-eks

# PR created automatically
# → terraform-plan.yml shows changes
# Approve PR and merge
# → terraform-apply.yml applies changes
```

### Scenario 3: Manual Infrastructure Deployment

Go to **Actions → Terraform Apply → Run workflow**

- Select environment: `dev`, `staging`, or `prod`
- Click **Run workflow**
- Workflow executes and deploys

---

## Security

### OIDC (No Long-Lived Credentials)

- Uses AWS OIDC provider (token.actions.githubusercontent.com)
- No AWS credentials stored in GitHub
- Tokens generated on-the-fly with 1-hour expiration

### Secrets Scanning

- Daily automated vulnerability scans
- Results visible in GitHub Security tab
- Trivy scans Docker images
- tfsec scans Terraform code
- Kubesec scans Kubernetes manifests

### Code Quality

- Terraform format checks
- ESLint for JavaScript
- Go security checks (gosec)
- npm audit for dependencies

---

## Troubleshooting

### Workflow stuck in "In Progress"

- Check if AWS credentials expired
- Verify `AWS_ROLE_ARN` is correct in secrets
- Ensure IAM role has proper trust relationship

### Docker images not pushing

- Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` in secrets
- Check Docker Hub account limits
- Look for rate-limiting errors in logs

### Terraform plan shows errors

- Verify `dev.tfvars` exists and has correct values
- Ensure S3 backend bucket exists and is accessible
- Check IAM permissions for AWS_ROLE_ARN

### K8s deployment fails

- Check if EKS cluster exists: `kubectl cluster-info`
- Verify kubeconfig updated: `aws eks update-kubeconfig --name dev-eks --region us-east-1`
- Check pod logs: `kubectl logs -l app=server`

---

## Monitoring & Dashboards

### GitHub Actions Dashboard

- **Settings → Actions → General** — Workflow statistics
- **Actions tab** — Individual workflow runs
- **Security tab** — Vulnerability scan results

### AWS CloudWatch

- **ECS/EKS** — Cluster metrics
- **RDS** — Database performance
- **CloudTrail** — API audit logs

### Kubernetes Monitoring

```bash
# Check pod status
kubectl get pods

# View logs
kubectl logs -l app=server

# Port-forward to test locally
kubectl port-forward svc/server 8080:80
```

---

## Best Practices

 **Always use PRs** — workflows validate code before merging
 **Review plan output** — check terraform-plan comments before approving
 **Keep secrets secure** — never commit `.tfvars` files
 **Monitor security scans** — check results in Security tab
 **Use branch protection** — require PR reviews before merge
 **Test manually first** — use `dev` environment before `staging`/`prod`

---

## Next Steps

1. **Add branch protection rules**:
   - Go to **Settings → Branches → Add rule**
   - Require PR reviews and passing checks before merge

2. **Add slack/email notifications**:
   - Integrate with GitHub Actions notify action
   - Get alerts on workflow failures

3. **Set up monitoring**:
   - CloudWatch dashboards for infrastructure
   - Prometheus/Grafana for applications

4. **Scale deployment**:
   - Add `staging` and `prod` environments
   - Implement blue-green deployments
   - Add rollback procedures

---

For questions or issues, check the [Troubleshooting](#troubleshooting) section or review individual workflow files.
