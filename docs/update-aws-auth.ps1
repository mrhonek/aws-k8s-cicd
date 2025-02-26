# Set variables - REPLACE THESE WITH YOUR VALUES
$GITHUB_ROLE = "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_GITHUB_ROLE_NAME"
$GITHUB_USERNAME = "github-actions"

# Get the existing aws-auth ConfigMap
Write-Host "Getting existing aws-auth ConfigMap..."
kubectl get configmap aws-auth -n kube-system -o yaml > existing-aws-auth.yaml

# Extract the existing mapRoles section
$existingConfig = Get-Content existing-aws-auth.yaml -Raw
$mapRolesSection = ""
if ($existingConfig -match "mapRoles:\s*\|([\s\S]*?)(?:\n\S|\z)") {
    $mapRolesSection = $Matches[1].Trim()
}

# Create the new ConfigMap content
$newConfig = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: $GITHUB_ROLE
      username: $GITHUB_USERNAME
      groups:
        - system:masters
$mapRolesSection
"@

# Save the new ConfigMap to a file
$newConfig | Out-File -FilePath new-aws-auth.yaml -Encoding ascii

Write-Host "Generated new ConfigMap:"
Get-Content new-aws-auth.yaml

# Apply the new ConfigMap
Write-Host "Applying updated aws-auth ConfigMap..."
kubectl apply -f new-aws-auth.yaml

Write-Host "ConfigMap updated successfully!"
Write-Host "Verifying aws-auth ConfigMap:"
kubectl get configmap aws-auth -n kube-system -o yaml

Write-Host "Done!" 