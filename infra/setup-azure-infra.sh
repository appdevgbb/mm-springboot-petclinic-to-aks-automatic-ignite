#!/usr/bin/env bash

# Azure Bicep Deployment Script
set -e

# Configuration
RESOURCE_GROUP_NAME="petclinic-workshop-rg"
LOCATION="West US 3"
DEPLOYMENT_NAME="aks-bicep-deployment-$(date +%Y%m%d-%H%M%S)"
PARAMETERS_FILE="parameters.json"

echo "Azure Bicep Deployment Script"
echo "=============================="

# Check prerequisites
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "Please log in to Azure CLI..."
    az login
fi

# Get current user info
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
CURRENT_USER_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || echo "")

if [ -n "$CURRENT_USER_ID" ] && [ -n "$CURRENT_USER_UPN" ]; then
    echo "Current user: $CURRENT_USER_UPN"
else
    echo "Warning: Could not retrieve Azure AD information"
    echo "Please provide azureADObjectId and azureADUserPrincipalName manually"
fi

# Validate and deploy
echo "Validating Bicep files..."
if [ -n "$CURRENT_USER_ID" ] && [ -n "$CURRENT_USER_UPN" ]; then
    az deployment sub validate \
        --location "$LOCATION" \
        --template-file main.bicep \
        --parameters @$PARAMETERS_FILE \
        --parameters resourceGroupName="$RESOURCE_GROUP_NAME" \
        --parameters location="$LOCATION" \
        --parameters azureADObjectId="$CURRENT_USER_ID" \
        --parameters azureADUserPrincipalName="$CURRENT_USER_UPN" \
        --parameters userAssignedIdentityName="petclinic-app-uami-yqkjlqj5mgv34" \
        --parameters acrName="petclinicacr" \
        --output none
else
    echo "Error: Could not retrieve Azure AD information. Please check your login status."
    exit 1
fi

echo "Deploying infrastructure (this may take 10-15 minutes)..."
az deployment sub create \
    --location "$LOCATION" \
    --name $DEPLOYMENT_NAME \
    --template-file main.bicep \
    --parameters @$PARAMETERS_FILE \
    --parameters resourceGroupName="$RESOURCE_GROUP_NAME" \
    --parameters location="$LOCATION" \
    --parameters azureADObjectId="$CURRENT_USER_ID" \
    --parameters azureADUserPrincipalName="$CURRENT_USER_UPN" \
    --parameters userAssignedIdentityName="petclinic-app-uami-yqkjlqj5mgv34" \
    --parameters acrName="petclinicacr" \
    --output table

echo "Deployment completed successfully!"
echo ""

# Get resource information from Bicep deployment outputs
echo "Retrieving resource information from Bicep deployment outputs..."
DEPLOYMENT_OUTPUTS=$(az deployment sub show --name $DEPLOYMENT_NAME --query properties.outputs -o json)

# Extract values from deployment outputs
AKS_CLUSTER_NAME=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.aksClusterName.value')
AKS_CLUSTER_FQDN=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.aksClusterFqdn.value')
AKS_CLUSTER_ID=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.aksClusterId.value')
POSTGRES_SERVER_NAME=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.postgresServerName.value')
POSTGRES_SERVER_FQDN=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.postgresServerFqdn.value')
POSTGRES_DATABASE_NAME=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.postgresDatabaseName.value')
POSTGRES_DATABASE_ID=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.postgresDatabaseId.value')
ACR_NAME=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.acrName.value')
ACR_LOGIN_SERVER=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.acrLoginServer.value')
USER_ASSIGNED_IDENTITY_CLIENT_ID=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.userAssignedIdentityClientId.value')
USER_ASSIGNED_IDENTITY_RESOURCE_ID=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.userAssignedIdentityId.value')

# Create azure.env file (always replace existing)
echo "Creating/updating azure.env file..."
cat > azure.env << EOF
# Azure Resource Information for Spring PetClinic Deployment
export RESOURCE_GROUP_NAME="$RESOURCE_GROUP_NAME"
export AKS_CLUSTER_NAME="$AKS_CLUSTER_NAME"
export AKS_CLUSTER_FQDN="$AKS_CLUSTER_FQDN"
export AKS_CLUSTER_ID="$AKS_CLUSTER_ID"

# PostgreSQL Connection Information
export POSTGRES_SERVER_NAME="$POSTGRES_SERVER_NAME"
export POSTGRES_SERVER_FQDN="$POSTGRES_SERVER_FQDN"
export POSTGRES_DATABASE_NAME="petclinic"
export POSTGRES_DATABASE_ID="$POSTGRES_DATABASE_ID"

# Azure Container Registry Information
export ACR_NAME="$ACR_NAME"
export ACR_LOGIN_SERVER="$ACR_LOGIN_SERVER"

# User Assigned Managed Identity Information (PostgreSQL)
export USER_ASSIGNED_IDENTITY_CLIENT_ID="$USER_ASSIGNED_IDENTITY_CLIENT_ID"
export USER_ASSIGNED_IDENTITY_RESOURCE_ID="$USER_ASSIGNED_IDENTITY_RESOURCE_ID"

# Deployment Commands
export AKS_GET_CREDENTIALS="az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME"
export ACR_LOGIN="az acr login --name $ACR_NAME"
EOF

echo "azure.env file created successfully!"
echo ""

# Create Service Connectors using Azure CLI
echo "Creating Service Connectors..."
echo "=============================="

# Check if serviceconnector-passwordless extension is installed
if ! az extension list --query "[?name=='serviceconnector-passwordless']" -o tsv | grep -q "serviceconnector-passwordless"; then
    echo "Installing serviceconnector-passwordless extension..."
    az extension add --name serviceconnector-passwordless
fi

# Function to check if a service connector exists
check_service_connector_exists() {
    local connection_name="$1"
    
    echo "Checking if service connector '$connection_name' exists..."
    
    # List existing connections for the AKS cluster
    local existing_connections=$(az aks connection list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$AKS_CLUSTER_NAME" \
        --query "[?name=='$connection_name'].name" \
        -o tsv 2>/dev/null || echo "")
    
    if [ -n "$existing_connections" ]; then
        echo "  ✓ Service connector '$connection_name' already exists"
        return 0
    else
        echo "  ✗ Service connector '$connection_name' does not exist"
        return 1
    fi
}

# Function to apply Azure Policy audit mode to AKS cluster
# we need this otherwise the service connector creation fails due to policy restrictions
azure_policy_audit() {
    echo "Applying Azure Policy audit mode to AKS cluster..."
    az policy assignment update   --name "aks-deployment-safeguards-policy-assignment"   --scope "/subscriptions/6edaa0d4-86e4-431f-a3e2-d027a34f03c9/resourcegroups/petclinic-workshop-rg/providers/microsoft.containerservice/managedclusters/aks-petclinic-py2t5evhiqdr4"   --params '{
        "effect": {"value": "Audit"},
        "allowedContainerImagesRegex": {"value": ".*"},
        "allowedGroups": {"value": ["system:node"]},
        "allowedUsers": {"value": ["nodeclient", "system:serviceaccount:kube-system:aci-connector-linux", "system:serviceaccount:kube-system:node-controller", "acsService", "aksService", "system:serviceaccount:kube-system:cloud-node-manager"]},
        "cpuLimit": {"value": "2"},
        "excludedNamespaces": {"value": ["kube-system", "calico-system", "tigera-system", "gatekeeper-system"]},
        "labels": {"value": ["kubernetes.azure.com"]},
        "memoryLimit": {"value": "1Gi"},
        "reservedTaints": {"value": ["CriticalAddonsOnly"]},
        "warn": {"value": true}
    }'
}

# Function to create PostgreSQL service connector
create_postgres_connector() {
    local connection_name="pg"
    
    if check_service_connector_exists "$connection_name"; then
        echo "Skipping PostgreSQL connector creation - already exists"
        return 0
    fi
    
    echo "Creating PostgreSQL service connector..."
    
    azure_policy_audit 

    az aks connection create postgres-flexible \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$AKS_CLUSTER_NAME" \
        --connection "$connection_name" \
        --target-id "$POSTGRES_DATABASE_ID" \
        --workload-identity "$USER_ASSIGNED_IDENTITY_RESOURCE_ID" \
        --yes \
        --output table
    
    echo "✓ PostgreSQL service connector created successfully"
}



# Create service connectors
echo "Creating Service Connectors for:"
echo "  AKS Cluster: $AKS_CLUSTER_NAME"
echo "  PostgreSQL Database: $POSTGRES_DATABASE_ID"
echo "  User Assigned Identity: $USER_ASSIGNED_IDENTITY_RESOURCE_ID"
echo ""

create_postgres_connector
echo ""

echo "Service Connector creation completed successfully!"
echo ""

# List all connections for verification
echo "Verifying created connections..."
az aks connection list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --query "[].{Name:name,TargetService:properties.targetService.id,AuthType:properties.authInfo.authType}" \
    --output table

echo ""
echo "Infrastructure deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. Source the environment file:"
echo "   source azure.env"
echo ""
echo "2. Get AKS credentials:"
echo "   \$AKS_GET_CREDENTIALS"
echo ""
echo "3. Configure Azure RBAC authentication for kubectl:"
echo "   kubelogin convert-kubeconfig --login azurecli"
echo ""
echo "4. Test AKS access:"
echo "   kubectl get pods"
echo ""
echo "5. Login to ACR for image push:"
echo "   \$ACR_LOGIN"
echo ""
echo "6. Build and push your container image:"
echo "   docker build -t \$ACR_LOGIN_SERVER/petclinic:latest ."
echo "   docker push \$ACR_LOGIN_SERVER/petclinic:latest"
echo ""
echo "7. Deploy to AKS using the generated Kubernetes manifests"
echo ""
echo "Environment variables available for Spring PetClinic deployment:"
echo "   - AKS_CLUSTER_NAME: \$AKS_CLUSTER_NAME"
echo "   - AKS_CLUSTER_FQDN: \$AKS_CLUSTER_FQDN"
echo "   - POSTGRES_SERVER_FQDN: \$POSTGRES_SERVER_FQDN"
echo "   - ACR_LOGIN_SERVER: \$ACR_LOGIN_SERVER"
echo "   - USER_ASSIGNED_IDENTITY_CLIENT_ID: \$USER_ASSIGNED_IDENTITY_CLIENT_ID"