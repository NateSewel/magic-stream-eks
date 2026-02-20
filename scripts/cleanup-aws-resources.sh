#!/bin/bash
# AWS Resource Cleanup Script for MagicStreamMastery
# Cleans up resources with dependencies before terraform destroy
# Usage: ./cleanup-aws-resources.sh [environment]

set -e

ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE} AWS Cleanup - $ENVIRONMENT Environment${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to get AWS Account ID
get_account_id() {
    aws sts get-caller-identity --query Account --output text
}

# Function to clean up Kubernetes resources
cleanup_kubernetes() {
    echo -e "${BLUE}Step 1: Cleaning up Kubernetes resources...${NC}"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}⚠ kubectl not found, skipping Kubernetes cleanup${NC}"
        return
    fi
    
    # Update kubeconfig
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig \
        --name "$ENVIRONMENT-eks" \
        --region "$AWS_REGION" 2>/dev/null || {
        echo -e "${YELLOW}⚠ Could not access EKS cluster${NC}"
        return
    }
    
    # Delete services (which will trigger removal of LoadBalancers)
    echo "Deleting Kubernetes services..."
    kubectl delete svc --all -n default --ignore-not-found 2>/dev/null || true
    kubectl delete svc --all -n kube-system --ignore-not-found 2>/dev/null || true
    
    # Wait for LoadBalancers to be removed
    echo "Waiting for LoadBalancers to be removed..."
    sleep 15
    
    # Delete deployments
    echo "Deleting Kubernetes deployments..."
    kubectl delete deployment --all -n default --ignore-not-found 2>/dev/null || true
    
    # Delete PVCs (persistent volume claims)
    echo "Deleting persistent volume claims..."
    kubectl delete pvc --all -n default --ignore-not-found 2>/dev/null || true
    
    # Delete namespaces
    echo "Deleting namespaces..."
    kubectl delete namespace argocd sealed-secrets --ignore-not-found 2>/dev/null || true
    
    echo -e "${GREEN}✓ Kubernetes cleanup complete${NC}"
}

# Function to clean up Elastic IPs
cleanup_elastic_ips() {
    echo ""
    echo -e "${BLUE}Step 2: Cleaning up Elastic IPs...${NC}"
    
    # Get VPC ID
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=$ENVIRONMENT-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        echo -e "${YELLOW}⚠ VPC not found, skipping EIP cleanup${NC}"
        return
    fi
    
    echo "Found VPC: $VPC_ID"
    
    # Find and disassociate EIPs
    EIPS=$(aws ec2 describe-addresses \
        --filters "Name=domain,Values=vpc" \
        --query "Addresses[?AssociationId!=null].AllocationId" \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$EIPS" ]; then
        echo "No Elastic IPs found"
    else
        echo "Disassociating Elastic IPs..."
        for eip in $EIPS; do
            ASSOC_ID=$(aws ec2 describe-addresses \
                --allocation-ids "$eip" \
                --query 'Addresses[0].AssociationId' \
                --output text \
                --region "$AWS_REGION" 2>/dev/null || echo "")
            
            if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
                echo "  Disassociating $eip..."
                aws ec2 disassociate-address \
                    --association-id "$ASSOC_ID" \
                    --region "$AWS_REGION" 2>/dev/null || true
                sleep 2
            fi
        done
    fi
    
    echo -e "${GREEN}✓ Elastic IP cleanup complete${NC}"
}

# Function to clean up Network Interfaces
cleanup_network_interfaces() {
    echo ""
    echo -e "${BLUE}Step 3: Cleaning up Network Interfaces...${NC}"
    
    # Get VPC ID
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=$ENVIRONMENT-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        echo -e "${YELLOW}⚠ VPC not found${NC}"
        return
    fi
    
    # Find detached ENIs
    echo "Looking for orphaned network interfaces..."
    ENIS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
        --query 'NetworkInterfaces[?Description!=`ELB net interface`].NetworkInterfaceId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$ENIS" ]; then
        echo "No orphaned network interfaces found"
    else
        echo "Deleting orphaned network interfaces..."
        for eni in $ENIS; do
            echo "  Deleting $eni..."
            aws ec2 delete-network-interface \
                --network-interface-id "$eni" \
                --region "$AWS_REGION" 2>/dev/null || true
            sleep 1
        done
    fi
    
    echo -e "${GREEN}✓ Network interface cleanup complete${NC}"
}

# Function to clean up RDS instances
cleanup_rds() {
    echo ""
    echo -e "${BLUE}Step 4: Cleaning up RDS resources...${NC}"
    
    # Find RDS instances
    DB_INSTANCES=$(aws rds describe-db-instances \
        --query "DBInstances[?contains(DBInstanceIdentifier, '$ENVIRONMENT')].DBInstanceIdentifier" \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$DB_INSTANCES" ]; then
        echo "No RDS instances found"
    else
        echo "Deleting RDS final snapshots..."
        for db_instance in $DB_INSTANCES; do
            echo "  Deleting final snapshot for $db_instance..."
            aws rds delete-db-instance \
                --db-instance-identifier "$db_instance" \
                --skip-final-snapshot \
                --region "$AWS_REGION" 2>/dev/null || true
            sleep 2
        done
    fi
    
    echo -e "${GREEN}✓ RDS cleanup complete${NC}"
}

# Main execution
echo -e "${YELLOW}Prerequisites: aws-cli, kubectl (optional)${NC}"
echo ""

cleanup_kubernetes
cleanup_elastic_ips
cleanup_network_interfaces
cleanup_rds

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✓ AWS Resource Cleanup Complete${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Run: terraform destroy -auto-approve"
echo "2. If still getting errors, check AWS Console for remaining resources"
echo "3. Manually delete any stubborn resources from AWS Console"
echo ""
