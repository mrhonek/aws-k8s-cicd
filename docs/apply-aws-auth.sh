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
NODE_ROLE="arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_NODE_ROLE_NAME"

echo -e "${CYAN}=== AWS Auth ConfigMap Application Script ===${NC}"
echo -e "This script will apply the aws-auth ConfigMap to your EKS cluster."

# Configure kubectl
echo -e "\n${CYAN}Configuring kubectl...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION || {
  echo -e "${RED}Error: Failed to update kubeconfig${NC}"
  exit 1
}

# Create aws-auth ConfigMap YAML
echo -e "\n${CYAN}Creating aws-auth ConfigMap...${NC}"
cat > aws-auth-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${GITHUB_ROLE}
      username: github-actions
      groups:
        - system:masters
    - rolearn: ${NODE_ROLE}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

# Apply the ConfigMap
echo -e "\n${CYAN}Applying aws-auth ConfigMap...${NC}"
kubectl apply -f aws-auth-configmap.yaml || {
  echo -e "${RED}Error: Failed to apply aws-auth ConfigMap${NC}"
  exit 1
}

# Verify the ConfigMap
echo -e "\n${CYAN}Verifying aws-auth ConfigMap...${NC}"
kubectl get configmap aws-auth -n kube-system -o yaml

echo -e "\n${GREEN}aws-auth ConfigMap has been applied successfully!${NC}"
echo -e "GitHub Actions should now be able to authenticate to the EKS cluster." 