#!/bin/bash
# Script to test EKS access

# Set variables
AWS_REGION="us-west-1"
EKS_CLUSTER_NAME="portfolio-cluster"

echo "Testing EKS access for cluster $EKS_CLUSTER_NAME in region $AWS_REGION"

# Verify AWS credentials
echo "=== Verifying AWS identity ==="
aws sts get-caller-identity

# Update kubeconfig
echo -e "\n=== Updating kubeconfig ==="
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

# Get EKS cluster info
echo -e "\n=== Getting EKS cluster info ==="
aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --query "cluster.status"

# Test kubectl
echo -e "\n=== Testing kubectl access ==="
kubectl get nodes || echo "Failed to get nodes - authentication issue"

# Check aws-auth ConfigMap
echo -e "\n=== Checking aws-auth ConfigMap ==="
kubectl get configmap aws-auth -n kube-system -o yaml || echo "Failed to get aws-auth ConfigMap"

# Check IAM roles in aws-auth ConfigMap
echo -e "\n=== IAM roles in aws-auth ConfigMap ==="
kubectl get configmap aws-auth -n kube-system -o yaml | grep -A5 "mapRoles"

# Show all services
echo -e "\n=== Kubernetes services ==="
kubectl get svc --all-namespaces || echo "Failed to get services"

echo -e "\n=== Test complete ===" 