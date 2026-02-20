# Secure Application Deployment Guide

This guide shows how to securely deploy MagicStreamMastery with Terraform-managed secrets.

## Prerequisites

- `terraform >= 1.14.0`
- `aws-cli` configured
- `kubectl` and `kustomize`
- AWS account with EKS permissions
- OpenAI API key
- MongoDB Atlas connection URI

## Setup Steps

### 1. Create Secure Variables File

```bash
cd infrastructure/terraform/environments/dev

# Copy example file
cp example.tfvars dev.tfvars

# Edit with your actual secrets (don't commit this!)
nano dev.tfvars
```

**Fill in:**

```hcl
db_password                  = "your-rds-password"
openai_api_key               = "sk-proj-..."
mongodb_uri                  = "mongodb+srv://user:pass@cluster.mongodb.net/db?appName=..."
secret_key                   = "generate-a-random-32-char-string"
refresh_token_secret_key     = "generate-another-random-32-char-string"
allowed_origins              = "http://localhost:3000"  # or production domain
```

### 2. Verify `.gitignore`

Ensure `dev.tfvars` is in `.gitignore`:

```bash
echo "*.tfvars" >> .gitignore
echo "*.tfvars.json" >> .gitignore
```

### 3. Plan Infrastructure

```bash
terraform init
terraform plan -var-file="dev.tfvars"
```

**Review the plan carefully** — secrets will show as `(sensitive)` and not print values.

### 4. Apply Infrastructure

```bash
terraform apply -var-file="dev.tfvars"
```

This will:

-  Provision VPC, EKS cluster, RDS, S3
-  Create Kubernetes ConfigMap (`magic-stream-api-config`) with non-sensitive config
-  Create Kubernetes Secret (`magic-stream-api-secrets`) with encrypted secrets
-  Automatically authenticate to the new EKS cluster

### 5. Navigate to Kubernetes Directory

```bash
cd ../../../kubernetes/base
```

### 6. Deploy Applications

```bash
# Update kubeconfig
aws eks update-kubeconfig --name dev-eks --region us-east-1

# Apply Kubernetes manifests (uses ConfigMap and Secret)
kubectl apply -k .

# Check deployment status
kubectl get pods
kubectl get svc

# View logs
kubectl logs -l app=server --tail=50
```

### 7. Verify Secrets Are Properly Injected

```bash
# Get a pod name
POD=$(kubectl get pods -l app=server -o jsonpath='{.items[0].metadata.name}')

# Check that env vars are set
kubectl exec -it $POD -- env | grep MONGODB_URI
kubectl exec -it $POD -- env | grep OPENAI_API_KEY

# Should print values (but they won't be visible in kubectl output for security)
```

## Security Architecture

```
┌─────────────────────────────────────┐
│  Terraform Variables (dev.tfvars)   │  ← NOT in git
├─────────────────────────────────────┤
│  Terraform State (S3 encrypted)     │  ← Encrypted at rest
├─────────────────────────────────────┤
│  Kubernetes Secret (ETCD encrypted) │  ← Reference in Deployment
├─────────────────────────────────────┤
│  Pod Environment Variables          │  ← Available to app
└─────────────────────────────────────┘
```

## Changing Secrets

If you need to update a secret:

```bash
cd infrastructure/terraform/environments/dev

# Edit the value
nano dev.tfvars

# Re-apply (Kubernetes will automatically update pods)
terraform apply -var-file="dev.tfvars"
```

**Note**: Kubernetes Secrets in ETCD are base64-encoded, NOT encrypted by default. For production, enable ETCD encryption:

```bash
aws eks update-cluster-config \
  --name dev-eks \
  --encryption-config resources=secrets,provider=aws:kms,keyArn=arn:aws:kms:region:account:key/id
```

## Production Recommendations

1. **Use AWS Secrets Manager** instead of Kubernetes Secrets:

   ```hcl
   resource "aws_secretsmanager_secret" "app_secrets" {
     name = "magic-stream-api-secrets"
   }
   ```

2. **Enable ETCD encryption** for the EKS cluster

3. **Rotate secrets regularly** (at least quarterly)

4. **Use SOPS/Sealed Secrets** for additional encryption layer:

   ```bash
   # Encrypt secrets before storing in git
   sops --encrypt dev.tfvars > dev.tfvars.enc
   ```

5. **Audit secret access**:
   ```bash
   # Check who accessed secrets
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=ResourceName,AttributeValue=magic-stream-api-secrets
   ```

## Troubleshooting

### Error: "configMapRef" not found

Ensure Terraform apply completed successfully and ConfigMap exists:

```bash
kubectl get configmap magic-stream-api-config
```

### Error: "secretRef" not found

Ensure Terraform apply created the Secret:

```bash
kubectl get secret magic-stream-api-secrets
```

### Pods can't connect to MongoDB

Check the MONGODB_URI is correct:

```bash
POD=$(kubectl get pods -l app=server -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -- mongosh "$MONGODB_URI"
```

### OPENAI_API_KEY seems invalid

Verify the key in dev.tfvars starts with `sk-` and is not truncated:

```bash
grep OPENAI dev.tfvars
```

## Cleanup

To destroy all resources (including secrets):

```bash
terraform destroy -var-file="dev.tfvars"
```

**Important**: After destroy, securely delete `dev.tfvars`:

```bash
shred -vfz -n 3 dev.tfvars  # Linux/macOS
# On Windows, use: cipher /w:C: (full disk wipe)
```
