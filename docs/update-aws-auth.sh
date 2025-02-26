#!/bin/bash
set -e

# Set variables
GITHUB_ROLE="arn:aws:iam::537124942860:role/github-actions-role"
GITHUB_USERNAME="github-actions"

# Get the existing aws-auth ConfigMap
echo "Getting existing aws-auth ConfigMap..."
kubectl get configmap aws-auth -n kube-system -o yaml > existing-aws-auth.yaml

# Extract only the existing mapRoles section (without the leading spaces)
EXISTING_MAP_ROLES=$(grep -A 1000 "mapRoles:" existing-aws-auth.yaml | tail -n +2 | sed 's/^  //')

# Create a temporary file with the new ConfigMap
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
${EXISTING_MAP_ROLES}
EOF

echo "Generated new ConfigMap:"
cat new-aws-auth.yaml

# Apply the new ConfigMap
echo "Applying updated aws-auth ConfigMap..."
kubectl apply -f new-aws-auth.yaml

echo "ConfigMap updated successfully!"
echo "Verifying aws-auth ConfigMap:"
kubectl get configmap aws-auth -n kube-system -o yaml

echo "Done!" 