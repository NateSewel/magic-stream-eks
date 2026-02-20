#!/bin/bash
# Clean up orphaned Terraform state entries and reconcile
# Run from infrastructure/terraform/environments/dev

set -e

ENVIRONMENT="dev"

echo "🧹 Cleaning up orphaned state entries..."

# Remove resources that don't exist in AWS yet but are in state
echo "Removing non-existent EBS CSI resources from state..."
terraform state rm "module.eks.aws_iam_role.ebs_csi" 2>/dev/null || true
terraform state rm "module.eks.aws_iam_role_policy_attachment.ebs_csi_policy_irsa" 2>/dev/null || true
terraform state rm "module.eks.aws_iam_openid_connect_provider.eks" 2>/dev/null || true
terraform state rm "module.eks.aws_eks_addon.ebs_csi" 2>/dev/null || true

# Remove node group and addon for re-import with correct format
echo "Removing node group for re-import with correct format..."
terraform state rm "module.eks.aws_eks_node_group.main" 2>/dev/null || true

# Re-import node group with corrected format (cluster-name:node-group-name)
echo "Re-importing node group with corrected format..."
terraform import "module.eks.aws_eks_node_group.main" "${ENVIRONMENT}-eks:${ENVIRONMENT}-node-group" 2>/dev/null || true

# Re-import addon with corrected format (cluster-name:addon-name)
echo "Re-importing EBS CSI addon with corrected format..."
terraform import "module.eks.aws_eks_addon.ebs_csi" "${ENVIRONMENT}-eks:aws-ebs-csi-driver" 2>/dev/null || true

echo ""
echo "✅ Cleanup complete! Next, run:"
echo "   terraform plan -var=\"db_password=securepassword\" | head -50"
echo "   terraform apply -var=\"db_password=securepassword\""
