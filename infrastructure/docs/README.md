# Infrastructure README

## Prerequisites
- Terraform >= 1.14.0
- AWS CLI configured with administrator permissions
- kubectl and kustomize
- Pre-created S3 backend buckets (use `scripts/bootstrap/bootstrap-backend.sh`)

## Project Structure
- `modules/`: Reusable infrastructure components (VPC, EKS, RDS, S3, ASG).
- `environments/`: Environment-specific configurations (`dev`, `staging`, `prod`).
- `kubernetes/`: Kubernetes manifests using Kustomize.

## Deployment Steps

### 1. Bootstrap Backend
```bash
./scripts/bootstrap/bootstrap-backend.sh
```

### 2. Provision Infrastructure (e.g., Dev)
```bash
cd infrastructure/terraform/environments/dev
terraform init
terraform plan -var="db_password=securepassword"
terraform apply -var="db_password=securepassword"
```

### 3. Deploy to Kubernetes
```bash
# Update kubeconfig
aws eks update-kubeconfig --name dev-eks --region us-east-1

# Apply manifests
kubectl apply -k infrastructure/kubernetes/base
```

## Common Operations
- **Scale Node Group**: Modify `scaling_config` in `environments/dev/main.tf` and apply.
- **Drift Detection**: Run `terraform plan` on a schedule.
- **RDS Management**: Access DB through the ASG bastion host using the exported endpoint.
