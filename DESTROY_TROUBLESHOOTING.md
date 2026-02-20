# Terraform Destroy Troubleshooting Guide

## Problem Summary

When running `terraform destroy`, you're encountering dependency errors:

1. **Subnet deletion failures** - Subnets have attached ENIs
2. **Internet Gateway detachment failures** - VPC has mapped public addresses (Elastic IPs)

These errors occur because Kubernetes LoadBalancer services create AWS resources (Network Interfaces, Elastic IPs) that must be cleaned up before Terraform can destroy the underlying network infrastructure.

## Root Causes

### Why This Happens

When you deploy applications to Kubernetes with `LoadBalancer` type services:

1. Kubernetes creates AWS Network Load Balancers
2. NLBs provision Elastic IPs for public access
3. NLBs create Elastic Network Interfaces (ENIs) in your subnets
4. These resources have dependencies on VPC, subnets, and internet gateways

When Terraform tries to destroy resources in reverse dependency order, it attempts to delete subnets before the ENIs are removed, causing the error.

### Dependency Chain

```
Internet Gateway
    ↓
VPC with mapped public addresses (Elastic IPs)
    ↓
Subnets with attached ENIs
    ↓
Network Load Balancer (created by K8s Service)
    ↓
Kubernetes Service (LoadBalancer type)
```

## Solution Steps

### Step 1: Clean Up Kubernetes Resources (Automatic)

The cleanup scripts handle this automatically:

**Linux/macOS/WSL:**

```bash
chmod +x scripts/cleanup-aws-resources.sh
./scripts/cleanup-aws-resources.sh dev us-east-1
```

**Windows PowerShell:**

```powershell
.\scripts\cleanup-aws-resources.ps1 -Environment dev -Region us-east-1
```

This will:

- ✓ Delete Kubernetes services (triggers NLB removal)
- ✓ Wait 15 seconds for AWS to remove resources
- ✓ Disassociate Elastic IPs
- ✓ Delete orphaned Network Interfaces
- ✓ Clean up RDS instances

### Step 2: Verify AWS Resource Cleanup

Check that LoadBalancers are removed:

```bash
# List Network Load Balancers
aws elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName'

# List Elastic IPs
aws ec2 describe-addresses --query 'Addresses[?AssociationId!=null]'

# List Network Interfaces by VPC
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=vpc-08853c48b0639c626" \
  --query 'NetworkInterfaces[].NetworkInterfaceId'
```

### Step 3: Run Terraform Destroy

Once cleanup is complete, destroy the infrastructure:

```bash
cd infrastructure/terraform/environments/dev
terraform destroy -auto-approve
```

### Step 4: If Errors Still Occur

If you still get dependency errors after cleanup:

#### Option A: Remove Specific Resources from State

```bash
# Remove problematic resources from state (they won't be destroyed)
terraform state rm 'module.vpc.aws_internet_gateway.main'
terraform state rm 'module.vpc.aws_subnet.private'
terraform state rm 'module.vpc.aws_subnet.public'

# Try destroy again
terraform destroy -auto-approve
```

#### Option B: Manual AWS Resource Cleanup

If automation doesn't fully work, manually remove stuck resources:

```bash
# 1. Get the VPC ID
VPC_ID="vpc-08853c48b0639c626"

# 2. Find and delete Network Interfaces manually
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[].NetworkInterfaceId' \
  --output text | xargs -I {} \
  aws ec2 delete-network-interface --network-interface-id {}

# 3. Wait a few seconds
sleep 10

# 4. Try destroying again
terraform destroy -auto-approve
```

#### Option C: Force Delete via AWS Console

If CLI methods fail:

1. Go to AWS Console → EC2 → Network Interfaces
2. Filter by VPC ID: `vpc-08853c48b0639c626`
3. Select all available interfaces
4. Right-click → Delete
5. Go to EC2 → Load Balancers
6. Delete any remaining LoadBalancers
7. Go to VPC → Elastic IPs
8. Disassociate any remaining EIPs
9. Run `terraform destroy` again

## Best Practices to Avoid This Issue

### 1. Always Clean Up Kubernetes Before Destroy

Create a pre-destroy checklist:

```bash
# Before running terraform destroy:
kubectl delete svc --all -n default
kubectl delete deployment --all -n default
kubectl delete pvc --all -n default

# Wait for LoadBalancers to be removed (check AWS Console)
sleep 20

# Then run destroy
terraform destroy -auto-approve
```

### 2. Use Terraform Destroy Order

Modify your Terraform to ensure proper destruction order. Add this to your Terraform modules:

```hcl
# In your kubernetes provider setup
provider "kubernetes" {
  depends_on = [module.eks]

  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_get_token.cluster.token
}

# Ensure Kubernetes resources are destroyed before VPC
resource "null_resource" "cleanup_kubernetes" {
  triggers = {
    cluster_id = module.eks.cluster_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete svc --all 2>/dev/null || true"
  }

  depends_on = [kubernetes_service.main]
}
```

### 3. Monitor ElasticIP Allocation

Track EIPs to prevent orphaned allocations:

```bash
# Regularly check for orphaned EIPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null]' \
  --output table

# Release orphaned EIPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].AllocationId' \
  --output text | xargs -I {} \
  aws ec2 release-address --allocation-id {}
```

## Detailed Error Reference

### Error 1: Subnet Dependency Violation

```
Error: deleting EC2 Subnet (subnet-07ea9fb902df5a7b8):
operation error EC2: DeleteSubnet... DependencyViolation:
The subnet 'subnet-07ea9fb902df5a7b8' has dependencies
and cannot be deleted.
```

**Cause:** Network Interfaces still attached to subnet

**Fix:**

1. Delete Kubernetes services (removes NLBs)
2. Delete orphaned Network Interfaces
3. Try `terraform destroy` again

### Error 2: Internet Gateway Detach Error

```
Error: deleting EC2 Internet Gateway (igw-01b6d410ecfaa6055):
detaching EC2 Internet Gateway... DependencyViolation:
Network vpc-08853c48b0639c626 has some mapped public address(es).
Please unmap those public address(es) before detaching the gateway.
```

**Cause:** Elastic IPs still associated with resources

**Fix:**

1. Disassociate all Elastic IPs in VPC
2. Release unneeded Elastic IP allocations
3. Try `terraform destroy` again

## Script Reference

### cleanup-aws-resources.sh (Bash/Linux)

Automatically handles:

- Kubernetes resource deletion
- EIP disassociation
- Network interface cleanup
- RDS instance removal

**Usage:**

```bash
./scripts/cleanup-aws-resources.sh [environment] [region]
```

### cleanup-aws-resources.ps1 (PowerShell)

Same functionality as Bash version for Windows users.

**Usage:**

```powershell
.\scripts\cleanup-aws-resources.ps1 -Environment dev -Region us-east-1
```

## Quick Reference: Common Destroy Issues

| Issue                   | Cause                       | Solution                             |
| ----------------------- | --------------------------- | ------------------------------------ |
| Subnet has dependencies | ENIs still attached         | Delete K8s services, cleanup scripts |
| IGW detach fails        | EIPs mapped to VPC          | Disassociate all EIPs                |
| RDS deletion hangs      | Snapshots creating          | Use `skip-final-snapshot` flag       |
| EKS won't delete        | Cluster still has resources | Delete all pods in cluster first     |
| VPC in use              | Resources still exist       | Clean up all resources in order      |

## Prevention Checklist

Before running `terraform destroy`:

- [ ] Run cleanup script: `./cleanup-aws-resources.sh dev`
- [ ] Verify no LoadBalancers exist: `aws elbv2 describe-load-balancers`
- [ ] Verify no EIPs associated: `aws ec2 describe-addresses | grep AssociationId`
- [ ] Delete orphaned ENIs: See cleanup scripts
- [ ] Wait 30 seconds for AWS consistency
- [ ] Run destroy: `terraform destroy -auto-approve`

## Support & Troubleshooting

If you're still experiencing issues:

1. **Check AWS Console** for remaining resources
2. **Review CloudTrail logs** for API errors
3. **Manually delete** any stubborn resources
4. **Check Terraform state** for discrepancies: `terraform state list`
5. **Use state removal** for truly stuck resources: `terraform state rm <resource>`

For questions about specific errors, reference the AWS documentation:

- https://docs.aws.amazon.com/vpc/latest/userguide/
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/
- https://docs.aws.amazon.com/eks/latest/userguide/
