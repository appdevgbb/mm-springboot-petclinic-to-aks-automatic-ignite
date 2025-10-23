#!/usr/bin/env bash

set -euo pipefail

# Required variables
RESOURCE_GROUP_NAME="rg-petclinic"
LOCATION="westus3"
NAME_SUFFIX=$(openssl rand -hex 4)  # Generates 8-character random suffix

# Resource names
AKS_CLUSTER_NAME="aks-petclinic"
POSTGRES_SERVER_NAME="db-petclinic${NAME_SUFFIX:0:4}"
POSTGRES_DATABASE_NAME="petclinic"
USER_ASSIGNED_IDENTITY_NAME="mi-petclinic"
ACR_NAME="acrpetclinic${NAME_SUFFIX:0:6}"

# create reource group
az group create --name ${RESOURCE_GROUP_NAME} --location ${LOCATION}

# Create User Assigned Managed Identity
echo "Creating User Assigned Managed Identity: ${USER_ASSIGNED_IDENTITY_NAME}"

az identity create \
  --name ${USER_ASSIGNED_IDENTITY_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --location ${LOCATION} 

# Capture the identity details
USER_ASSIGNED_IDENTITY_ID=$(az identity show \
  --name ${USER_ASSIGNED_IDENTITY_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --query id \
  --output tsv)

USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az identity show \
  --name ${USER_ASSIGNED_IDENTITY_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --query clientId \
  --output tsv)

USER_ASSIGNED_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name ${USER_ASSIGNED_IDENTITY_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --query principalId \
  --output tsv)

# Create PostgreSQL Flexible Server
az postgres flexible-server create \
  --name ${POSTGRES_SERVER_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --location ${LOCATION} \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 15 \
  --storage-size 32 \
  --storage-auto-grow Enabled \
  --microsoft-entra-auth Enabled \
  --password-auth Disabled

echo "PostgreSQL Flexible Server created: ${POSTGRES_SERVER_NAME}"

# Create PostgreSQL Database
echo "Creating PostgreSQL database: ${POSTGRES_DATABASE_NAME}"

az postgres flexible-server db create \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --server-name ${POSTGRES_SERVER_NAME} \
  --database-name ${POSTGRES_DATABASE_NAME}

# Capture database ID
POSTGRES_DATABASE_ID=$(az postgres flexible-server db show \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --server-name ${POSTGRES_SERVER_NAME} \
  --database-name ${POSTGRES_DATABASE_NAME} \
  --query id \
  --output tsv)

echo "PostgreSQL database created: ${POSTGRES_DATABASE_NAME}"

# Create Azure Container Registry
echo "Creating Azure Container Registry: ${ACR_NAME}"

az acr create \
  --name ${ACR_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --location ${LOCATION} \
  --sku Basic

# Capture ACR details
ACR_LOGIN_SERVER=$(az acr show \
  --name ${ACR_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --query loginServer \
  --output tsv)

echo "Azure Container Registry created: ${ACR_NAME}"
echo "  Login Server: ${ACR_LOGIN_SERVER}"

# Create AKS Automatic Cluster
az aks create \
  --name ${AKS_CLUSTER_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --location ${LOCATION} \
  --sku automatic \
  --attach-acr ${ACR_NAME}

# Capture AKS cluster ID
AKS_CLUSTER_ID=$(az aks show \
  --name ${AKS_CLUSTER_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --query id \
  --output tsv)

AKS_CLUSTER_FQDN=$(az aks show \
  --name ${AKS_CLUSTER_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --query fqdn \
  --output tsv)

az aks get-credentials \
  --name ${AKS_CLUSTER_NAME} \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --file "${AKS_CLUSTER_NAME}-kubeconfig"

echo "AKS Automatic cluster created: ${AKS_CLUSTER_NAME}"
echo "  FQDN: ${AKS_CLUSTER_FQDN}"

# Connect AKS to PostgreSQL using Service Connector Passwordless
az extension add --name serviceconnector-passwordless --upgrade

az aks connection create postgres-flexible \
--source-id ${AKS_CLUSTER_ID} \
--target-id ${POSTGRES_DATABASE_ID} \
--workload-identity ${USER_ASSIGNED_IDENTITY_ID} \
--client-type none \
--kube-namespace default

# -----------------------------------------------------------------------------
# Assign AKS Admin Role to Current User (Optional)
# -----------------------------------------------------------------------------
if [ "${DEPLOY_AZURE_RBAC}" = "true" ] && [ -n "${AZURE_AD_OBJECT_ID}" ]; then
  echo "Assigning AKS RBAC Cluster Admin role to user"
  
  az role assignment create \
    --assignee ${AZURE_AD_OBJECT_ID} \
    --role "Azure Kubernetes Service RBAC Cluster Admin" \
    --scope ${AKS_CLUSTER_ID}
  
  echo "AKS RBAC Cluster Admin role assigned to user"
fi


# Optional - Set these if you want to assign admin roles to a specific user
DEPLOY_AZURE_RBAC="false"  # Set to "true" to enable
AZURE_AD_USER_EMAIL=""      # e.g., "user@contoso.com"
AZURE_AD_OBJECT_ID=""       # Azure AD Object ID of the user
