targetScope = 'resourceGroup'

param nameSuffix string

@description('The name of the AKS cluster')
@minLength(1)
@maxLength(63)
param aksClusterName string = 'aks-petclinic'

@description('The name of the PostgreSQL Flexible Server')
@minLength(1)
@maxLength(12)
param postgresServerName string = 'db-petclinic'

@description('PostgreSQL database name')
@minLength(1)
@maxLength(10)
param postgresDatabaseName string = 'petclinic'

@description('Whether to deploy the AKS Admin and PostgreSQL Entra ID Admin Role Assignments (requires azureADUserPrincipalName and azureADObjectId parameters)')
param deployAzureRBACForCurrentUser bool = false

@description('Azure AD User Principal Name of the user to set as PostgreSQL admin')
param azureADUserPrincipalName string = ''

@description('The Object ID of the Azure AD user to set as PostgreSQL admin')
param azureADObjectId string = ''

@description('Name of the User Assigned Managed Identity for the application')
@minLength(1)
@maxLength(12)
param userAssignedIdentityName string = 'mi-petclinic'

@description('Name of the Azure Container Registry')
@minLength(5)
@maxLength(12)
param acrName string = 'acrpetclinic'

@description('Name of the Azure Policy Assignment to update to Audit mode (for service connector creation)')
param policyAssignmentName string = 'aks-deployment-safeguards-policy-assignment'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Development'
  Project: 'PetClinic'
  ManagedBy: 'Bicep'
}

// Create User Assigned Managed Identity for PostgreSQL access
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentityName
  location: resourceGroup().location
  tags: tags
}

// Log Analytics Workspace for AKS monitoring
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-petclinic${substring(nameSuffix, 0, 4)}'
  location: resourceGroup().location
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
  name: '${postgresServerName}${substring(nameSuffix, 0, 4)}'
  location: resourceGroup().location
  sku: {
    name: 'Standard_B1ms' // Development profile - Burstable tier
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
resource postgresAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-11-01-preview' = if (deployAzureRBACForCurrentUser) {
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
  name: '${acrName}${substring(nameSuffix, 0, 4)}'
  location: resourceGroup().location
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
resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-08-02-preview' = {
  name: aksClusterName
  location: resourceGroup().location
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

// // Service Linker from AKS to PostgreSQL using the User Assigned Managed Identity
// resource serviceLinker 'Microsoft.ServiceLinker/linkers@2024-07-01-preview' = {
//   scope: aksCluster
//   name: 'postgres'
//   properties: {
//     clientType: 'none'
//     scope: 'default'
//     targetService: {
//       type: 'AzureResource'
//       id: postgresServer.id
//     }
//     authInfo: {
//       authType: 'userAssignedIdentity'
//       clientId: userAssignedIdentity.properties.clientId
//       subscriptionId: subscription().subscriptionId
//     }
//   }
// }

// Role assignment: Grant AcrPull to AKS kubelet managed identity
resource aksAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, acr.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    ) // AcrPull role
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Azure Kubernetes Service RBAC Cluster Admin - for administrative permissions within the cluster
resource aksRbacClusterAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployAzureRBACForCurrentUser) {
  name: guid(aksCluster.id, azureADObjectId, 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
    ) // Azure Kubernetes Service RBAC Cluster Admin
    principalId: azureADObjectId
    principalType: 'User'
  }
}

// Note: Policy assignment update is handled in the bash deployment script (setup-azure-infra.sh)
// to avoid Azure CLI deployment bugs with deployment script resources

// Outputs - Essential information for Spring PetClinic deployment
output resourceGroupName string = resourceGroup().name
output resourceGroupId string = resourceGroup().id
output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output aksClusterId string = aksCluster.id
output postgresServerId string = postgresServer.id
output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output postgresDatabaseName string = postgresDatabase.name
output postgresDatabaseId string = postgresDatabase.id
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output userAssignedIdentityId string = userAssignedIdentity.id
output userAssignedIdentityClientId string = userAssignedIdentity.properties.clientId
output userAssignedIdentityPrincipalId string = userAssignedIdentity.properties.principalId
output policyAssignmentName string = policyAssignmentName
