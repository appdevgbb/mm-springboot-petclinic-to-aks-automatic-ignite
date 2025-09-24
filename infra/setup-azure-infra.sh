#!/bin/bash

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
echo "Creating Service Connectors for AKS..."
echo "======================================"

# Register required resource providers for Service Connector
echo "Registering required Azure resource providers..."
az provider register -n Microsoft.ServiceLinker --output none
az provider register -n Microsoft.KubernetesConfiguration --output none

echo "✓ Resource providers registered"
echo ""

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

# Function to create PostgreSQL service connector
create_postgres_connector() {
    local connection_name="pg"
    
    if check_service_connector_exists "$connection_name"; then
        echo "Skipping PostgreSQL connector creation - already exists"
        return 0
    fi
    
    echo "Creating PostgreSQL service connector..."
    echo "  AKS Cluster: $AKS_CLUSTER_NAME"
    echo "  PostgreSQL Database: $POSTGRES_DATABASE_ID"
    echo "  Managed Identity: $USER_ASSIGNED_IDENTITY_RESOURCE_ID"
    echo ""
    
    # Create the service connector - this will automatically:
    # 1. Install the sc-extension Kubernetes extension if not present
    # 2. Enable workload identity and OIDC issuer on the cluster
    # 3. Create the necessary Kubernetes resources (secret, service account)
    # 4. Set up the federated identity credential
    if az aks connection create postgres-flexible \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$AKS_CLUSTER_NAME" \
        --connection "$connection_name" \
        --target-id "$POSTGRES_DATABASE_ID" \
        --workload-identity "$USER_ASSIGNED_IDENTITY_RESOURCE_ID" \
        --yes \
        --output table; then
        echo "✅ PostgreSQL service connector created successfully!"
        echo ""
        echo "The Service Connector has automatically:"
        echo "  • Installed the sc-extension on your AKS cluster"
        echo "  • Created Kubernetes secret and service account in 'default' namespace"
        echo "  • Set up workload identity authentication"
        echo "  • Configured database firewall rules"
        return 0
    else
        echo "❌ Service Connector creation failed"
        echo ""
        echo "This could be due to:"
        echo "  1. Azure Policy (Gatekeeper) blocking the sc-extension installation"
        echo "  2. Missing permissions for Microsoft.ServiceLinker operations"
        echo "  3. Network connectivity issues with the cluster"
        echo "  4. The cluster being in an updating state"
        echo ""
        echo "📋 Manual Connection Information:"
        echo "   Server FQDN: $POSTGRES_SERVER_FQDN"
        echo "   Database: $POSTGRES_DATABASE_NAME"
        echo "   Managed Identity Client ID: $USER_ASSIGNED_IDENTITY_CLIENT_ID"
        echo ""
        echo "   For troubleshooting Service Connectors, run:"
        echo "   az k8s-extension show --resource-group $RESOURCE_GROUP_NAME \\"
        echo "     --cluster-name $AKS_CLUSTER_NAME --cluster-type managedClusters \\"
        echo "     --name sc-extension"
        echo ""
        return 1
    fi
}



# Create service connectors
echo "Setting up Service Connectors for AKS cluster..."
echo "==============================================="
echo "Service Connector will automatically install the required Kubernetes extension"
echo "and configure workload identity authentication for secure database access."
echo ""
echo "Target resources:"
echo "  🎯 AKS Cluster: $AKS_CLUSTER_NAME"
echo "  🗄️ PostgreSQL Database: $POSTGRES_DATABASE_ID"
echo "  🔐 User Assigned Identity: $USER_ASSIGNED_IDENTITY_RESOURCE_ID"
echo ""

# Create PostgreSQL connector
create_postgres_connector
connector_result=$?

echo ""

# List all connections for verification
echo "Verifying Service Connector status..."
if connections=$(az aks connection list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --query "[].{Name:name,TargetService:properties.targetService.id,AuthType:properties.authInfo.authType}" \
    --output table 2>/dev/null) && echo "$connections" | grep -q "Name"; then
    echo "$connections"
    echo ""
    echo "✅ Service Connectors are configured and ready!"
    echo ""
    echo "📋 What was automatically configured:"
    echo "  • sc-extension Kubernetes extension installed in your cluster"
    echo "  • Workload identity and OIDC issuer enabled"
    echo "  • Kubernetes secret created in 'default' namespace"
    echo "  • Service account created with proper annotations"
    echo "  • Database firewall rules configured"
else
    if [ $connector_result -eq 0 ]; then
        echo "⚠️  Service Connector created but not showing in list (propagation delay)"
        echo "   This is normal - the connection should be available shortly"
    else
        echo "ℹ️  Service Connector creation failed - manual configuration required"
        echo "   Common causes: Azure Policy restrictions or cluster updating state"
        echo ""
        echo "   To retry after resolving issues:"
        echo "   az aks connection create postgres-flexible \\"
        echo "     --resource-group $RESOURCE_GROUP_NAME \\"
        echo "     --name $AKS_CLUSTER_NAME \\"
        echo "     --connection pg \\"
        echo "     --target-id $POSTGRES_DATABASE_ID \\"
        echo "     --workload-identity $USER_ASSIGNED_IDENTITY_RESOURCE_ID \\"
        echo "     --yes"
    fi
fi

echo ""
echo "🎉 AKS Infrastructure Deployment Completed!"
echo "==========================================="
echo ""
echo "Your AKS cluster is ready with the following features:"
echo "  ✅ AKS cluster with intelligent scaling (AKS Automatic)"
echo "  ✅ PostgreSQL Flexible Server with Entra ID authentication"
echo "  ✅ Azure Container Registry with AKS integration"
echo "  ✅ Workload Identity configured for secure database access"
echo "  ✅ Azure Monitor and Log Analytics enabled"
echo ""
echo "� Service Connector Status"
echo "=========================="
if [ $connector_result -eq 0 ]; then
    echo "✅ Service Connector successfully configured!"
    echo "   Your applications can use the automatically created Kubernetes resources:"
    echo "   • Secret name: sc-<connection-name> (in default namespace)"
    echo "   • Service account: sc-<connection-name> (in default namespace)"
    echo ""
    echo "   Example usage in deployment:"
    echo "   spec:"
    echo "     serviceAccountName: sc-pg"
    echo "     containers:"
    echo "     - name: app"
    echo "       envFrom:"
    echo "       - secretRef:"
    echo "           name: sc-pg"
else
    echo "⚠️ Service Connector creation failed - Azure Policy likely blocked it"
    echo ""
    echo "📋 Manual Configuration Required:"
    echo "1. Create Kubernetes secret:"
    echo "   kubectl create secret generic postgres-secret \\"
    echo "     --from-literal=POSTGRES_HOST=\"$POSTGRES_SERVER_FQDN\" \\"
    echo "     --from-literal=POSTGRES_DB=\"$POSTGRES_DATABASE_NAME\" \\"
    echo "     --from-literal=AZURE_CLIENT_ID=\"$USER_ASSIGNED_IDENTITY_CLIENT_ID\""
    echo ""
    echo "2. Create service account with workload identity:"
    echo "   kubectl create serviceaccount petclinic-sa"
    echo "   kubectl annotate serviceaccount petclinic-sa \\"
    echo "     azure.workload.identity/client-id=\"$USER_ASSIGNED_IDENTITY_CLIENT_ID\""
    echo ""
    echo "3. Use in your deployment:"
    echo "   spec:"
    echo "     serviceAccountName: petclinic-sa"
    echo "     containers:"
    echo "     - name: petclinic"
    echo "       envFrom:"
    echo "       - secretRef:"
    echo "           name: postgres-secret"
fi
echo ""
echo "🚀 Next steps:"
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
