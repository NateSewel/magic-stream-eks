#!/bin/bash
# Import existing EKS and IAM resources into Terraform state
# Run this from infrastructure/terraform/environments/dev

set -e

ENVIRONMENT="dev"
REGION="us-east-1"

echo "Importing EKS resources into Terraform state..."

# Import IAM Roles
echo "Importing IAM roles..."
terraform import "module.eks.aws_iam_role.cluster" "${ENVIRONMENT}-eks-cluster-role" || true
terraform import "module.eks.aws_iam_role.nodes" "${ENVIRONMENT}-eks-node-role" || true
terraform import "module.eks.aws_iam_role.ebs_csi" "${ENVIRONMENT}-ebs-csi-role" || true

# Import IAM Policy Attachments
echo "Importing IAM policy attachments..."
terraform import "module.eks.aws_iam_role_policy_attachment.cluster_policy" "${ENVIRONMENT}-eks-cluster-role/AmazonEKSClusterPolicy" || true

# Import node policy attachments (for_each resources)
terraform import 'module.eks.aws_iam_role_policy_attachment.node_policy["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]' "${ENVIRONMENT}-eks-node-role/AmazonEKSWorkerNodePolicy" || true
terraform import 'module.eks.aws_iam_role_policy_attachment.node_policy["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]' "${ENVIRONMENT}-eks-node-role/AmazonEKS_CNI_Policy" || true
terraform import 'module.eks.aws_iam_role_policy_attachment.node_policy["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]' "${ENVIRONMENT}-eks-node-role/AmazonEC2ContainerRegistryReadOnly" || true

# Import EBS CSI policy attachment
terraform import "module.eks.aws_iam_role_policy_attachment.ebs_csi_policy_irsa" "${ENVIRONMENT}-ebs-csi-role/AmazonEBSCSIDriverPolicy" || true

# Import EKS Cluster
echo "Importing EKS cluster..."
terraform import "module.eks.aws_eks_cluster.main" "${ENVIRONMENT}-eks" || true

# Import OIDC Provider
echo "Importing OIDC provider..."
# Get the OIDC provider ARN from the cluster
OIDC_ID=$(aws eks describe-cluster --name "${ENVIRONMENT}-eks" --region "${REGION}" --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)
terraform import "module.eks.aws_iam_openid_connect_provider.eks" "${OIDC_ID}" || true

# Import Node Group
echo "Importing node group..."
terraform import "module.eks.aws_eks_node_group.main" "${ENVIRONMENT}-eks/${ENVIRONMENT}-node-group" || true

# Import EBS CSI Addon
echo "Importing EBS CSI addon..."
terraform import "module.eks.aws_eks_addon.ebs_csi" "${ENVIRONMENT}-eks/aws-ebs-csi-driver" || true

echo "   Import complete! Now run:"
echo "   terraform plan"
echo "   terraform apply"
