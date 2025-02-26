#!/bin/bash
set -e

# Variables - REPLACE THESE WITH YOUR VALUES
GITHUB_ROLE="arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_GITHUB_ROLE_NAME"
CLUSTER_NAME="YOUR_CLUSTER_NAME"
REGION="YOUR_REGION"

# Configure kubectl
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Get current aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml > current-aws-auth.yaml

# Create a temporary file with updated auth
cat > aws-auth-update.yaml << EOF
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
EOF

# Apply the ConfigMap
kubectl apply -f aws-auth-update.yaml

# Verify
kubectl get configmap aws-auth -n kube-system -o yaml

echo "Done!" 