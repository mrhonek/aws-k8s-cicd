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

echo -e "${CYAN}=== EKS Auth ConfigMap Fix Script ===${NC}"
echo -e "This script will diagnose and fix the EKS authentication for GitHub Actions.\n"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed.${NC}"
    exit 1
fi

# Check if aws is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed.${NC}"
    exit 1
fi

# Get AWS caller identity
echo -e "${CYAN}Checking AWS identity...${NC}"
aws sts get-caller-identity || {
    echo -e "${RED}Error: Could not get AWS identity. Please configure AWS CLI.${NC}"
    exit 1
}

# Configure kubectl for EKS
echo -e "\n${CYAN}Configuring kubectl for EKS...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION || {
    echo -e "${RED}Error: Could not update kubeconfig. Check if the cluster exists.${NC}"
    exit 1
}

# Check if aws-auth ConfigMap exists
echo -e "\n${CYAN}Checking if aws-auth ConfigMap exists...${NC}"
if ! kubectl get configmap aws-auth -n kube-system &> /dev/null; then
    echo -e "${RED}Warning: aws-auth ConfigMap doesn't exist. Creating it...${NC}"
    # Create an empty aws-auth ConfigMap
    cat > aws-auth-initial.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
EOF
    kubectl apply -f aws-auth-initial.yaml
fi

# Get the current aws-auth ConfigMap
echo -e "\n${CYAN}Getting current aws-auth ConfigMap...${NC}"
kubectl get configmap aws-auth -n kube-system -o yaml > current-aws-auth.yaml

# Check if the GitHub Actions role is already in the ConfigMap
echo -e "\n${CYAN}Checking if GitHub Actions role is in the ConfigMap...${NC}"
if grep -q "$GITHUB_ROLE" current-aws-auth.yaml; then
    echo -e "${GREEN}GitHub Actions role is already in the ConfigMap.${NC}"
    echo -e "Current aws-auth ConfigMap:"
    cat current-aws-auth.yaml
else
    echo -e "${RED}GitHub Actions role is NOT in the ConfigMap. Adding it...${NC}"
    
    # Extract existing mapRoles
    if grep -q "mapRoles:" current-aws-auth.yaml; then
        echo "mapRoles section found..."
        EXISTING_MAP_ROLES=$(grep -A 1000 "mapRoles:" current-aws-auth.yaml | tail -n +2 | sed 's/^  //')
    else
        echo "No mapRoles section found. Creating new section..."
        EXISTING_MAP_ROLES=""
    fi

    # Create a new aws-auth ConfigMap with the GitHub Actions role
    cat > new-aws-auth.yaml << EOF
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
EOF

    # If there were existing roles, append them
    if [ ! -z "$EXISTING_MAP_ROLES" ]; then
        echo "$EXISTING_MAP_ROLES" >> new-aws-auth.yaml
    fi

    # Show the new ConfigMap
    echo -e "\n${CYAN}New aws-auth ConfigMap:${NC}"
    cat new-aws-auth.yaml

    # Apply the new ConfigMap
    echo -e "\n${CYAN}Applying new aws-auth ConfigMap...${NC}"
    kubectl apply -f new-aws-auth.yaml

    # Verify the ConfigMap was updated
    echo -e "\n${CYAN}Verifying aws-auth ConfigMap...${NC}"
    kubectl get configmap aws-auth -n kube-system -o yaml
fi

# Additional verification steps
echo -e "\n${CYAN}Testing kubernetes access with current credentials...${NC}"
kubectl get nodes || echo -e "${RED}Cannot access nodes with current credentials${NC}"

echo -e "\n${CYAN}Testing access for github-actions user...${NC}"
kubectl auth can-i list pods --as=github-actions || echo -e "${RED}github-actions user cannot list pods${NC}"

# Check node groups to get the correct node role ARN
echo -e "\n${CYAN}Getting node group role ARNs for verification...${NC}"
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups[]' --output text)

if [ ! -z "$NODE_GROUPS" ]; then
    for ng in $NODE_GROUPS; do
        echo -e "Node group: $ng"
        NODE_ROLE=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng --region $REGION --query 'nodegroup.nodeRole' --output text)
        echo -e "Node role ARN: $NODE_ROLE"
        
        # Check if node role is in the ConfigMap
        if ! grep -q "$NODE_ROLE" new-aws-auth.yaml &> /dev/null; then
            echo -e "${RED}WARNING: Node role $NODE_ROLE is not in the aws-auth ConfigMap!${NC}"
            echo -e "This could prevent nodes from joining the cluster. Manual fix may be required."
        fi
    done
else
    echo "No node groups found."
fi

echo -e "\n${GREEN}aws-auth ConfigMap has been updated!${NC}"
echo -e "GitHub Actions should now be able to authenticate to the EKS cluster."
echo -e "Run the GitHub Actions workflow again to test." 