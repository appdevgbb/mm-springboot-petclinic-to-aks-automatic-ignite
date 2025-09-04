#!/bin/bash

# Spring Boot PetClinic Workshop - Azure Infrastructure Setup Script
# This script creates all required Azure resources for the workshop

set -e

# Generate random suffix for PostgreSQL server name
POSTGRES_SUFFIX=$(openssl rand -hex 3)
echo "🎲 Generated PostgreSQL suffix: $POSTGRES_SUFFIX"
LOCATION="eastus"
RESOURCE_GROUP="petclinic-workshop-rg"
AKS_CLUSTER="petclinic-workshop-aks"
POSTGRES_SERVER="petclinic-workshop-postgres-${POSTGRES_SUFFIX}"
POSTGRES_DB="petclinic"
POSTGRES_USER="petclinic_admin"
POSTGRES_PASSWORD="PetClinic2024!"
STORAGE_ACCOUNT="petclinicworkshopst"
CONTAINER_REGISTRY="petclinicworkshopacr"
MANAGED_IDENTITY="petclinic-workshop-identity"

echo "🚀 Starting Azure infrastructure setup for PetClinic workshop..."
echo "📍 Location: $LOCATION"
echo "🏷️  Resource Group: $RESOURCE_GROUP"
echo "🐘 PostgreSQL Server: $POSTGRES_SERVER"
echo "☸️  AKS Cluster: $AKS_CLUSTER"

# Check if user is logged into Azure
echo "🔐 Checking Azure login status..."
if ! az account show > /dev/null 2>&1; then
    echo "❌ Not logged into Azure. Please run 'az login' first."
    exit 1
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "✅ Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create resource group
echo "📦 Creating resource group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --tags workshop=petclinic-migration

# Create storage account for AKS
echo "💾 Creating storage account..."
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --encryption-services blob

# Create container registry
echo "🐳 Creating Azure Container Registry..."
az acr create \
    --name $CONTAINER_REGISTRY \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Basic \
    --admin-enabled true

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $CONTAINER_REGISTRY --query loginServer -o tsv)

# Create managed identity for workload identity
echo "🆔 Creating managed identity for workload identity..."
az identity create \
    --name $MANAGED_IDENTITY \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION

MANAGED_IDENTITY_ID=$(az identity show --name $MANAGED_IDENTITY --resource-group $RESOURCE_GROUP --query id -o tsv)
MANAGED_IDENTITY_CLIENT_ID=$(az identity show --name $MANAGED_IDENTITY --resource-group $RESOURCE_GROUP --query clientId -o tsv)
MANAGED_IDENTITY_PRINCIPAL_ID=$(az identity show --name $MANAGED_IDENTITY --resource-group $RESOURCE_GROUP --query principalId -o tsv)

# Create PostgreSQL Flexible Server
echo "🐘 Creating PostgreSQL Flexible Server..."
az postgres flexible-server create \
    --name $POSTGRES_SERVER \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --admin-user $POSTGRES_USER \
    --admin-password $POSTGRES_PASSWORD \
    --sku-name Standard_B1ms \
    --tier Burstable \
    --storage-size 32 \
    --version 15 \
    --yes

# Create database
echo "🗄️  Creating database..."
az postgres flexible-server db create \
    --resource-group $RESOURCE_GROUP \
    --server-name $POSTGRES_SERVER \
    --database-name $POSTGRES_DB

# Configure PostgreSQL firewall to allow Azure services
echo "🔥 Configuring PostgreSQL firewall..."
az postgres flexible-server firewall-rule create \
    --resource-group $RESOURCE_GROUP \
    --name $POSTGRES_SERVER \
    --rule-name AllowAzureServices \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0

# Create AKS Automatic cluster
echo "☸️  Creating AKS Automatic cluster..."
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER \
    --location $LOCATION \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --generate-ssh-keys \
    --node-count 2 \
    --node-vm-size Standard_DS2_v2 \
    --enable-addons monitoring \
    --enable-managed-identity \
    --attach-acr $CONTAINER_REGISTRY \
    --yes

# Get AKS cluster credentials
echo "🔑 Getting AKS cluster credentials..."
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER \
    --overwrite-existing

# Get AKS OIDC issuer URL
OIDC_ISSUER=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create federated identity credential for workload identity
echo "🔗 Creating federated identity credential..."
az identity federated-credential create \
    --name "petclinic-workshop-federated-credential" \
    --identity-name $MANAGED_IDENTITY \
    --resource-group $RESOURCE_GROUP \
    --issuer $OIDC_ISSUER \
    --subject "system:serviceaccount:default:petclinic-service-account" \
    --audience api://AzureADTokenExchange

# Create service connector for AKS to PostgreSQL
echo "🔌 Creating service connector..."
az webapp connection create postgres-flexible \
    --resource-group $RESOURCE_GROUP \
    --name "petclinic-aks-postgres-connector" \
    --target-resource-group $RESOURCE_GROUP \
    --server $POSTGRES_SERVER \
    --database $POSTGRES_DB \
    --client-type java \
    --system-identity \
    --yes

# Get PostgreSQL connection details
POSTGRES_FQDN=$(az postgres flexible-server show --resource-group $RESOURCE_GROUP --name $POSTGRES_SERVER --query fullyQualifiedDomainName -o tsv)

# Output connection details and next steps
echo ""
echo "🎉 Azure infrastructure setup completed successfully!"
echo ""
echo "📋 Connection Details:"
echo "   PostgreSQL Server: $POSTGRES_FQDN"
echo "   Database: $POSTGRES_DB"
echo "   Username: $POSTGRES_USER"
echo "   Password: $POSTGRES_PASSWORD"
echo "   AKS Cluster: $AKS_CLUSTER"
echo "   Container Registry: $ACR_LOGIN_SERVER"
echo ""
echo "🔗 Next Steps:"
echo "   1. Update your application.properties with the PostgreSQL connection details above"
echo "   2. Use Containerization Assist to generate Dockerfile and Kubernetes manifests"
echo "   3. Deploy your application to AKS using: kubectl apply -f k8s/"
echo ""
echo "🧹 To clean up all resources, run:"
echo "   az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""

# Export variables for use in other scripts
cat > .env << EOF
export POSTGRES_SERVER=$POSTGRES_FQDN
export POSTGRES_DB=$POSTGRES_DB
export POSTGRES_USER=$POSTGRES_USER
export POSTGRES_PASSWORD=$POSTGRES_PASSWORD
export AKS_CLUSTER=$AKS_CLUSTER
export ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
export MANAGED_IDENTITY_CLIENT_ID=$MANAGED_IDENTITY_CLIENT_ID
export RESOURCE_GROUP=$RESOURCE_GROUP
EOF

echo "📝 Environment variables saved to .env file"
echo "   Source this file with: source .env"
