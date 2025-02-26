#!/bin/bash
set -e

# EKS Authentication Diagnostic Script

# 1. Check AWS CLI configuration
echo -e "\033[0;36m=== AWS CLI Configuration ===\033[0m"
aws sts get-caller-identity

# 2. Check EKS access
echo -e "\n\033[0;36m=== EKS Access ===\033[0m"
aws eks list-clusters
CLUSTER_NAME="portfolio-cluster"
REGION="us-west-1"

# 3. Check authentication mode
echo -e "\n\033[0;36m=== EKS Cluster Authentication Mode ===\033[0m"
AUTH_MODE=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.accessConfig.authenticationMode' --output text)
echo "Authentication Mode: $AUTH_MODE"

# 4. Verify the GitHub Actions role
echo -e "\n\033[0;36m=== GitHub Actions Role ===\033[0m"
GITHUB_ROLE="arn:aws:iam::537124942860:role/github-actions-role"
ROLE_NAME="github-actions-role"
echo "Checking IAM role: $GITHUB_ROLE"
if aws iam get-role --role-name $ROLE_NAME > /dev/null 2>&1; then
    aws iam get-role --role-name $ROLE_NAME --query 'Role.[RoleName, Arn, CreateDate]' --output text
else
    echo "Error: Could not find role $ROLE_NAME"
fi

# 5. Check AWS Auth ConfigMap
echo -e "\n\033[0;36m=== AWS Auth ConfigMap ===\033[0m"
echo "Setting up kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
echo "Getting aws-auth ConfigMap..."
if kubectl get configmap aws-auth -n kube-system > /dev/null 2>&1; then
    kubectl get configmap aws-auth -n kube-system -o yaml
else
    echo "Error: Could not get aws-auth ConfigMap"
fi

# 6. Check access review
echo -e "\n\033[0;36m=== Kubernetes Access Review ===\033[0m"
echo "This simulates the access the GitHub Actions role would have:"
kubectl auth can-i list pods --as=github-actions || echo "Cannot list pods as github-actions"
kubectl auth can-i create deployments --as=github-actions || echo "Cannot create deployments as github-actions"

# 7. Diagnostic summary
echo -e "\n\033[0;32m=== Diagnostic Summary ===\033[0m"
echo "Based on this diagnostic check:"
echo "1. If the authentication mode is 'API' or 'API_AND_CONFIG_MAP', update both the aws-auth ConfigMap and IAM"
echo "2. If the GitHub Actions role doesn't exist or has incorrect permissions, create/update it"
echo "3. Make sure the aws-auth ConfigMap contains the correct role ARN mapping"
echo ""
echo "AWS CLI command to update the EKS cluster config (if authentication mode is 'CONFIG_MAP'):"
echo "aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"
echo ""
echo "If using IRSA (IAM Roles for Service Accounts):"
echo "Check the OIDC provider and service account configuration in your EKS cluster"

# 8. Check node groups and authentication
echo -e "\n\033[0;36m=== Node Groups and Node Role ARNs ===\033[0m"
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output text)
echo "Node Groups: $NODE_GROUPS"

for ng in $NODE_GROUPS; do
  echo "Details for Node Group: $ng"
  aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng --region $REGION --query 'nodegroup.nodeRole' --output text
done

# 9. Direct test of kubectl with AWS credentials
echo -e "\n\033[0;36m=== Direct kubectl test ===\033[0m"
echo "Testing direct kubectl access using current AWS credentials:"
kubectl get nodes || echo "Failed to get nodes with current credentials" 