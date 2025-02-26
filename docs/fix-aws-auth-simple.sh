#!/bin/bash
set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables
CLUSTER_NAME="portfolio-cluster"
REGION="us-west-1"
GITHUB_ROLE="arn:aws:iam::537124942860:role/github-actions-role"
GITHUB_USERNAME="github-actions"

echo -e "${CYAN}=== EKS Auth ConfigMap Fix Script (Simple Version) ===${NC}"
echo -e "This script will fix the EKS authentication for GitHub Actions.\n"

# Configure kubectl for EKS
echo -e "\n${CYAN}Configuring kubectl for EKS...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION || {
    echo -e "${RED}Error: Could not update kubeconfig. Check if the cluster exists.${NC}"
    exit 1
}

# Create the ConfigMap directly with kubectl patch
echo -e "\n${CYAN}Updating aws-auth ConfigMap with kubectl patch...${NC}"

# Create a patch file
cat > aws-auth-patch.yaml << EOF
data:
  mapRoles: |
    - rolearn: arn:aws:iam::537124942860:role/github-actions-role
      username: github-actions
      groups:
        - system:masters
    - rolearn: arn:aws:iam::537124942860:role/general-eks-node-group-20250225163213163000000001
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

# Apply the patch
echo -e "\n${CYAN}Applying patch to aws-auth ConfigMap...${NC}"
kubectl patch configmap/aws-auth -n kube-system --patch "$(cat aws-auth-patch.yaml)"

# Verify the ConfigMap was updated
echo -e "\n${CYAN}Verifying aws-auth ConfigMap...${NC}"
kubectl get configmap aws-auth -n kube-system -o yaml

# Additional verification steps
echo -e "\n${CYAN}Testing kubernetes access with current credentials...${NC}"
kubectl get nodes || echo -e "${RED}Cannot access nodes with current credentials${NC}"

echo -e "\n${CYAN}Testing access for github-actions user...${NC}"
kubectl auth can-i list pods --as=github-actions || echo -e "${RED}github-actions user cannot list pods${NC}"

echo -e "\n${GREEN}aws-auth ConfigMap has been updated!${NC}"
echo -e "GitHub Actions should now be able to authenticate to the EKS cluster."
echo -e "Run the GitHub Actions workflow again to test." 