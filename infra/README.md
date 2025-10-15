# Azure Bicep Deployment: PetClinic Workshop Infrastructure

This repository contains Azure Bicep templates to deploy a complete workshop environment with:

- **Azure Kubernetes Service (AKS)** with Automatic SKU
- **Azure Database for PostgreSQL Flexible Server** with Entra ID authentication
- **Service Linkers** for secure, passwordless connections

## Architecture

The deployment creates the following resources in a new resource group:

```
petclinic-workshop-rg/
├── AKS Cluster (Automatic SKU)
│   ├── System node pool (3 nodes)
│   ├── Log Analytics Workspace
│   ├── Monitoring addon
│   ├── System Assigned Managed Identity
│   └── Service Linker → PostgreSQL
├── PostgreSQL Flexible Server
│   ├── Development profile (Burstable B1ms)
│   ├── Database (petclinic)
│   ├── Entra ID Administrator
│   ├── Entra ID authentication only
│   └── Firewall rule (Azure services)
└── User Assigned Managed Identity
    └── Used by Service Linkers
```

## Prerequisites

- Azure CLI installed and configured
- Azure subscription with appropriate permissions
- Bash shell (for deployment script)

## Quick Start

1. **Clone or download the files**
2. **Update the parameters** in `parameters.json`:
   ```json
   {
     "resourceGroupName": {
       "value": "petclinic-workshop-rg"
     },
     "location": {
       "value": "westus3"
     }
   }
   ```
3. **Run the deployment script**:
   ```bash
   chmod +x setup-azure-infra.sh
   ./setup-azure-infra.sh
   ```

## Manual Deployment

If you prefer to deploy manually:

```bash
RAND=$RANDOM
export RAND
echo "Random resource identifier will be: ${RAND}"

LOCATION=swedencentral
RESOURCE_GROUP=rg-petclinic$RAND

# Deploy the infrastructure (creates resource group and all resources)
az group create \
--name $RESOURCE_GROUP \
--location $LOCATION

az deployment group create \
--resource-group $RESOURCE_GROUP \
--name petclinic-deployment-$RAND \
--template-file main.bicep \
--parameters nameSuffix=$RAND deployAzureRBACForCurrentUser=true azureADUserPrincipalName=$(az ad signed-in-user show --query mail -o tsv) azureADObjectId=$(az ad signed-in-user show --query id -o tsv)
```

## Configuration

### Parameters

| Parameter                  | Description                             | Default                                | Validation      |
| -------------------------- | --------------------------------------- | -------------------------------------- | --------------- |
| `resourceGroupName`        | Resource group name                     | `petclinic-workshop-rg`                | 1-90 chars      |
| `location`                 | Azure region                            | `westus3`                              | Valid region    |
| `aksClusterName`           | AKS cluster name                        | `petclinic-workshop-aks-{unique}`      | 1-63 chars      |
| `postgresServerName`       | PostgreSQL server name                  | `petclinic-workshop-postgres-{unique}` | 1-63 chars      |
| `postgresDatabaseName`     | Database name                           | `petclinic`                            | 1-63 chars      |
| `azureADObjectId`          | Azure AD Object ID for PostgreSQL admin | Auto-detected                          | Valid Object ID |
| `azureADUserPrincipalName` | Azure AD UPN for PostgreSQL admin       | Auto-detected                          | Valid UPN       |
| `userAssignedIdentityName` | User Assigned Managed Identity name     | `petclinic-app-uami`                   | 1-63 chars      |

### Resource Specifications

#### AKS Cluster

- **SKU**: Automatic (latest stable)
- **Kubernetes Version**: Latest stable (managed by AKS Automatic)
- **Node Pool**: 3 nodes, system pool
- **Identity**: System Assigned Managed Identity
- **Monitoring**: Enabled with Log Analytics and Azure Monitor

#### PostgreSQL Flexible Server

- **Tier**: Burstable (development profile)
- **SKU**: Standard_B1ms
- **Version**: PostgreSQL 15
- **Authentication**: Entra ID only (password auth disabled)
- **Storage**: 32 GB with auto-grow
- **Backup**: 7 days retention
- **High Availability**: Disabled (development)

## Post-Deployment

After successful deployment, you can:

### Connect to AKS

```bash
# Get the dynamically generated AKS cluster name
AKS_NAME=$(az aks list --resource-group petclinic-workshop-rg --query '[0].name' -o tsv)
az aks get-credentials --resource-group petclinic-workshop-rg --name $AKS_NAME
kubectl get nodes
```

### Connect to PostgreSQL

```bash
# Get the dynamically generated PostgreSQL server name
POSTGRES_NAME=$(az postgres flexible-server list --resource-group petclinic-workshop-rg --query '[0].name' -o tsv)
# Connect using Entra ID authentication
az postgres flexible-server connect \
  --name $POSTGRES_NAME \
  --database petclinic \
  --admin-user $(az ad signed-in-user show --query userPrincipalName -o tsv)
```

## File Structure

```
├── main.bicep                    # Main deployment template
├── resources.bicep               # Resource definitions
├── parameters.json               # Parameter values
├── setup-azure-infra.sh          # Deployment script
├── setup-local-lab-infra.sh      # Local development setup
├── debug-parameters.json         # Debug parameters
├── debug-service-linker.bicep    # Debug service linker template
└── README.md                     # This file
```

## Best Practices Implemented

- **Parameter validation** with min/max length constraints
- **Secure parameters** for sensitive data
- **Latest API versions** for all resources
- **Resource naming** with unique suffixes
- **Tagging strategy** for resource management
- **Modular structure** with separate resource definitions
- **Comprehensive outputs** for post-deployment access

## Service Linkers

This deployment includes Azure Service Linkers that create secure connections between your AKS cluster and the backend services:

### PostgreSQL Service Linker

- **Connection**: AKS → PostgreSQL Flexible Server
- **Authentication**: User Assigned Managed Identity
- **Benefits**: Automatic connection string management, secure authentication, no password management

### Managed Identity Architecture

- **AKS Identity**: System Assigned Managed Identity for cluster operations
- **Service Linker Identity**: User Assigned Managed Identity for application connections
- **Benefits**:
  - Separation of concerns between cluster and application identities
  - Service Linkers automatically handle data plane access
  - Entra ID admin provides management plane access for PostgreSQL

## Security Considerations

- PostgreSQL uses Entra ID authentication only (no passwords)
- AKS uses system-assigned managed identity for cluster operations
- Service Linkers use user-assigned managed identity for application connections
- Service Linkers provide secure, passwordless connections
- AKS has RBAC enabled by default
- Firewall rules restrict PostgreSQL access to Azure services
- All resources use minimum TLS 1.2

## Cost Optimization

- **Development profile** for PostgreSQL (burstable tier)
- **Automatic SKU** AKS (managed node scaling)
- **7-day backup retention** (minimum for development)

## Troubleshooting

### Common Issues

1. **Resource name conflicts**: Ensure unique names or use auto-generated ones
2. **Location availability**: Some resources may not be available in all regions
3. **Quota limits**: Check subscription quotas for compute resources
4. **Entra ID permissions**: Ensure the current user has appropriate permissions for PostgreSQL admin

### Validation

Before deployment, validate the templates:

```bash
az deployment sub validate \
  --location "westus3" \
  --template-file main.bicep \
  --parameters @parameters.json \
  --parameters resourceGroupName="petclinic-workshop-rg" \
  --parameters location="westus3"
```

### Cleanup

To remove all resources:

```bash
az group delete --name petclinic-workshop-rg --yes --no-wait
```

## Support

For issues or questions:

- Check Azure documentation for each service
- Review Bicep best practices documentation
- Validate templates before deployment

## License

This template is provided as-is for educational and development purposes.
