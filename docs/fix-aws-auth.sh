#!/bin/bash
set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables - REPLACE THESE WITH YOUR VALUES
CLUSTER_NAME="YOUR_CLUSTER_NAME"
REGION="YOUR_REGION"
GITHUB_ROLE="arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_GITHUB_ROLE_NAME"
GITHUB_USERNAME="github-actions"

echo -e "${CYAN}=== EKS Auth ConfigMap Fix Script ===${NC}"
echo -e "This script will fix the aws-auth ConfigMap to allow GitHub Actions to access the EKS cluster.\n"

# Ensure eksctl is installed
if ! command -v eksctl &> /dev/null; then
    echo -e "${RED}Error: eksctl is not installed.${NC}"
    echo -e "Please install eksctl using instructions at: https://eksctl.io/installation/"
    exit 1
fi

# Get current user ARN
echo -e "\n${CYAN}Getting current user ARN...${NC}"
CURRENT_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo -e "Current user ARN: ${CURRENT_USER_ARN}"

# Configure kubectl for EKS
echo -e "\n${CYAN}Configuring kubectl for EKS...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION || {
    echo -e "${RED}Error: Could not update kubeconfig. Check if the cluster exists.${NC}"
    exit 1
}

# Create the aws-auth-complete.yaml file
echo -e "\n${CYAN}Creating aws-auth-complete.yaml...${NC}"
cat > aws-auth-complete.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_GITHUB_ROLE_NAME
      username: github-actions
      groups:
        - system:masters
    - rolearn: arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_NODE_ROLE_NAME
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

# Apply the aws-auth ConfigMap
echo -e "\n${CYAN}Applying aws-auth ConfigMap...${NC}"
kubectl apply -f aws-auth-complete.yaml || {
    echo -e "${RED}Error: Could not apply the aws-auth ConfigMap.${NC}"
    exit 1
}

# Verify the ConfigMap was created correctly
echo -e "\n${CYAN}Verifying aws-auth ConfigMap...${NC}"
kubectl get configmap aws-auth -n kube-system -o yaml

# Verify access
echo -e "\n${CYAN}Testing kubernetes access with current credentials...${NC}"
kubectl get nodes || echo -e "${RED}Cannot access nodes with current credentials${NC}"

echo -e "\n${CYAN}Testing access for github-actions user...${NC}"
kubectl auth can-i list pods --as=github-actions || echo -e "${RED}github-actions user cannot list pods${NC}"

echo -e "\n${GREEN}aws-auth ConfigMap has been created successfully!${NC}"
echo -e "GitHub Actions should now be able to authenticate to the EKS cluster."
echo -e "Run the GitHub Actions workflow again to test." 