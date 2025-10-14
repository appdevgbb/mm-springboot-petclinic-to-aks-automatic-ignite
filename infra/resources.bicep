@description('The location for all resources')
param location string

@description('The name of the AKS cluster')
param aksClusterName string

@description('The name of the PostgreSQL Flexible Server')
param postgresServerName string

@description('PostgreSQL database name')
param postgresDatabaseName string

@description('Azure AD Object ID of the user to set as PostgreSQL admin')
param azureADObjectId string

@description('Azure AD User Principal Name of the user to set as PostgreSQL admin')
param azureADUserPrincipalName string

@description('Name of the User Assigned Managed Identity for the application')
param userAssignedIdentityName string

@description('Name of the Azure Container Registry')
param acrName string

@description('Name of the Azure Policy Assignment to update to Audit mode')
param policyAssignmentName string

@description('Tags to apply to all resources')
param tags object

// Create User Assigned Managed Identity for PostgreSQL access
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentityName
  location: location
  tags: tags
}

// Log Analytics Workspace for AKS monitoring
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: tags
}

// PostgreSQL Flexible Server with Development profile
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'  // Development profile - Burstable tier
    tier: 'Burstable'
  }
  properties: {
    version: '15'
    storage: {
      storageSizeGB: 32
      autoGrow: 'Enabled'
      tier: 'P4'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: subscription().tenantId
    }
    network: {
      publicNetworkAccess: 'Enabled' // Allow public access for lab simplicity
    }
  }
  tags: tags
}

// PostgreSQL Entra ID Administrator
resource postgresEntraAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  parent: postgresServer
  name: azureADObjectId
  properties: {
    principalName: azureADUserPrincipalName
    principalType: 'User'
    tenantId: subscription().tenantId
  }
}

// PostgreSQL Database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: postgresDatabaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL Firewall Rule removed - public access enabled for lab simplicity

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
  tags: tags
}

// AKS Automatic Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
  name: aksClusterName
  location: location
  sku: {
    name: 'Automatic'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        count: 3
      }
    ]
    addonProfiles: {
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
          useAADAuth: 'true'
        }
      }
    }
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {
          metricLabelsAllowlist: '*'
          metricAnnotationsAllowList: '*'
        }
      }
    }
  }
  tags: tags
}

// Service Linkers removed - will be created via Azure CLI for better idempotency

// Role assignment: Grant AcrPull to AKS kubelet managed identity
resource aksAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, acr.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Grant user access to AKS cluster for Azure RBAC for Kubernetes Authorization
// Azure Kubernetes Service Cluster User Role - required to fetch cluster credentials
resource aksClusterUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, azureADObjectId, '4abbcc35-e782-43d8-92c5-2d3f1bd2253f')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4abbcc35-e782-43d8-92c5-2d3f1bd2253f') // Azure Kubernetes Service Cluster User Role
    principalId: azureADObjectId
    principalType: 'User'
  }
}

// Azure Kubernetes Service RBAC Cluster Admin - for administrative permissions within the cluster
resource aksRbacClusterAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, azureADObjectId, 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b') // Azure Kubernetes Service RBAC Cluster Admin
    principalId: azureADObjectId
    principalType: 'User'
  }
}

// Note: Policy assignment update is handled in the bash deployment script (setup-azure-infra.sh)
// to avoid Azure CLI deployment bugs with deployment script resources

// Outputs - Essential information for Spring PetClinic deployment
output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output aksClusterId string = aksCluster.id
output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output postgresDatabaseName string = postgresDatabase.name
output postgresDatabaseId string = postgresDatabase.id
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output userAssignedIdentityId string = userAssignedIdentity.id
output userAssignedIdentityClientId string = userAssignedIdentity.properties.clientId
output userAssignedIdentityPrincipalId string = userAssignedIdentity.properties.principalId
