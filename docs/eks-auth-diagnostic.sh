#!/bin/bash
set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Variables - REPLACE THESE WITH YOUR VALUES
CLUSTER_NAME="YOUR_CLUSTER_NAME"
REGION="YOUR_REGION"
GITHUB_ROLE="arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_GITHUB_ROLE_NAME"
GITHUB_USERNAME="github-actions"

echo -e "${CYAN}=== EKS Authentication Diagnostic Tool ===${NC}"
echo -e "This script will help diagnose EKS authentication issues for GitHub Actions.\n"

# Verify AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed.${NC}"
    exit 1
fi

# Verify kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed.${NC}"
    exit 1
fi

# Check AWS identity
echo -e "\n${CYAN}1. Checking AWS identity...${NC}"
aws sts get-caller-identity || {
    echo -e "${RED}Error: Failed to get AWS identity. Please configure AWS credentials.${NC}"
    exit 1
}

# Configure kubectl for EKS
echo -e "\n${CYAN}2. Configuring kubectl for EKS...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION || {
    echo -e "${RED}Error: Failed to update kubeconfig. Check if cluster exists.${NC}"
    exit 1
}

# Check kubectl connectivity
echo -e "\n${CYAN}3. Testing kubectl connectivity...${NC}"
if kubectl get svc &> /dev/null; then
    echo -e "${GREEN}kubectl connected to the cluster successfully.${NC}"
else
    echo -e "${RED}Error: kubectl failed to connect to the cluster.${NC}"
    echo -e "This could be a sign of authentication issues."
fi

# Check aws-auth ConfigMap
echo -e "\n${CYAN}4. Checking aws-auth ConfigMap...${NC}"
if kubectl get configmap aws-auth -n kube-system &> /dev/null; then
    echo -e "${GREEN}aws-auth ConfigMap exists.${NC}"
    
    # Save the ConfigMap to a file
    kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-current.yaml
    
    # Check if GitHub Actions role is in the ConfigMap
    if grep -q "$GITHUB_ROLE" aws-auth-current.yaml; then
        echo -e "${GREEN}✓ GitHub Actions role is properly configured in aws-auth ConfigMap.${NC}"
    else
        echo -e "${RED}✗ GitHub Actions role is missing from aws-auth ConfigMap!${NC}"
        echo -e "${YELLOW}Recommendation: Run the fix-aws-auth.sh script to add the role.${NC}"
    fi
else
    echo -e "${RED}Error: aws-auth ConfigMap does not exist!${NC}"
    echo -e "${YELLOW}Recommendation: Run the fix-aws-auth.sh script to create it.${NC}"
fi

# Check GitHub Actions role permissions
echo -e "\n${CYAN}5. Testing GitHub Actions role permissions...${NC}"
if kubectl auth can-i list pods --as=$GITHUB_USERNAME &> /dev/null; then
    echo -e "${GREEN}✓ GitHub Actions ($GITHUB_USERNAME) has permission to list pods.${NC}"
else
    echo -e "${RED}✗ GitHub Actions ($GITHUB_USERNAME) does not have permission to list pods!${NC}"
    echo -e "${YELLOW}Recommendation: Check role mapping in aws-auth ConfigMap.${NC}"
fi

# Check node groups
echo -e "\n${CYAN}6. Checking node groups...${NC}"
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups[]' --output text)

if [ ! -z "$NODE_GROUPS" ]; then
    echo -e "${GREEN}Found $(echo $NODE_GROUPS | wc -w) node group(s).${NC}"
    
    for ng in $NODE_GROUPS; do
        echo -e "\n${CYAN}Inspecting node group: $ng${NC}"
        NODE_ROLE=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng --region $REGION --query 'nodegroup.nodeRole' --output text)
        echo -e "Node role ARN: $NODE_ROLE"
        
        # Check if node role is in the aws-auth ConfigMap
        if grep -q "$NODE_ROLE" aws-auth-current.yaml; then
            echo -e "${GREEN}✓ Node role is properly configured in aws-auth ConfigMap.${NC}"
        else
            echo -e "${RED}✗ Node role is missing from aws-auth ConfigMap!${NC}"
            echo -e "${YELLOW}Recommendation: Update aws-auth ConfigMap to include this node role.${NC}"
        fi
    done
else
    echo -e "${RED}No node groups found for the cluster.${NC}"
fi

# Check if nodes are joining the cluster
echo -e "\n${CYAN}7. Checking if nodes are joining the cluster...${NC}"
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ $NODE_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ $NODE_COUNT node(s) joined the cluster.${NC}"
else
    echo -e "${RED}✗ No nodes have joined the cluster!${NC}"
    echo -e "${YELLOW}Recommendation: Check node group configuration and aws-auth ConfigMap.${NC}"
fi

echo -e "\n${CYAN}=== Diagnostic Summary ===${NC}"
echo -e "1. AWS credentials: ${GREEN}Verified${NC}"
echo -e "2. Cluster connectivity: ${GREEN}Tested${NC}"
echo -e "3. aws-auth ConfigMap: ${GREEN}Checked${NC}"
echo -e "4. GitHub Actions permissions: ${GREEN}Tested${NC}"
echo -e "5. Node groups: ${GREEN}Inspected${NC}"
echo -e "6. Node joining: ${GREEN}Checked${NC}"

echo -e "\n${CYAN}=== Recommendations ===${NC}"
echo -e "- If GitHub Actions workflow is failing with authentication issues:"
echo -e "  - Ensure the GitHub Actions role ARN is correct"
echo -e "  - Verify the role has the necessary permissions"
echo -e "  - Check if aws-auth ConfigMap is properly configured"
echo -e "- Run fix-aws-auth.sh to automatically fix common issues"
echo -e "- For persistent issues, refer to the EKS documentation for troubleshooting steps" 