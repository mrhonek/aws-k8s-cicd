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
NODE_ROLE="arn:aws:iam::537124942860:role/general-eks-node-group-20250225163213163000000001"

echo -e "${CYAN}=== EKS Auth ConfigMap Direct Apply Script ===${NC}"
echo -e "This script will apply a complete aws-auth ConfigMap for EKS authentication.\n"

# Configure kubectl for EKS
echo -e "\n${CYAN}Configuring kubectl for EKS...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION || {
    echo -e "${RED}Error: Could not update kubeconfig. Check if the cluster exists.${NC}"
    exit 1
}

# Create a complete aws-auth ConfigMap file
echo -e "\n${CYAN}Creating aws-auth ConfigMap...${NC}"
cat > aws-auth-complete.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${GITHUB_ROLE}
      username: ${GITHUB_USERNAME}
      groups:
        - system:masters
    - rolearn: ${NODE_ROLE}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

# Display the ConfigMap
echo -e "\n${CYAN}Generated aws-auth ConfigMap:${NC}"
cat aws-auth-complete.yaml

# Apply the ConfigMap
echo -e "\n${CYAN}Applying aws-auth ConfigMap...${NC}"
kubectl apply -f aws-auth-complete.yaml

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