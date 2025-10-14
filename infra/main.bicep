targetScope = 'resourceGroup'

@description('The location for all resources')
param location string

@description('The name of the AKS cluster')
@minLength(1)
@maxLength(63)
param aksClusterName string = 'aks-petclinic'

@description('The name of the PostgreSQL Flexible Server')
@minLength(1)
@maxLength(63)
param postgresServerName string = 'postgres-petclinic'

@description('PostgreSQL database name')
@minLength(1)
@maxLength(63)
param postgresDatabaseName string = 'petclinic'

@description('Azure AD Object ID of the user to set as PostgreSQL admin')
param azureADObjectId string

@description('Azure AD User Principal Name of the user to set as PostgreSQL admin')
param azureADUserPrincipalName string

@description('Name of the User Assigned Managed Identity for the application')
@minLength(1)
@maxLength(63)
param userAssignedIdentityName string = 'petclinic-app-uami'

@description('Name of the Azure Container Registry')
@minLength(5)
@maxLength(50)
param acrName string = 'petclinicacr'

@description('Name of the Azure Policy Assignment to update to Audit mode (for service connector creation)')
param policyAssignmentName string = 'aks-deployment-safeguards-policy-assignment'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Development'
  Project: 'PetClinic'
  ManagedBy: 'Bicep'
}

// Deploy resources to the existing resource group
module resources 'resources.bicep' = {
  name: 'deploy-resources'
  params: {
    location: location
    aksClusterName: '${aksClusterName}-${uniqueString(resourceGroup().id)}'
    postgresServerName: '${postgresServerName}-${uniqueString(resourceGroup().id)}'
    postgresDatabaseName: postgresDatabaseName
    azureADObjectId: azureADObjectId
    azureADUserPrincipalName: azureADUserPrincipalName
    userAssignedIdentityName: userAssignedIdentityName
    acrName: '${acrName}${uniqueString(resourceGroup().id)}'
    policyAssignmentName: policyAssignmentName
    tags: tags
  }
}

// Outputs - Essential information for Spring PetClinic deployment
output resourceGroupName string = resourceGroup().name
output resourceGroupId string = resourceGroup().id
output aksClusterName string = resources.outputs.aksClusterName
output aksClusterFqdn string = resources.outputs.aksClusterFqdn
output aksClusterId string = resources.outputs.aksClusterId
output postgresServerName string = resources.outputs.postgresServerName
output postgresServerFqdn string = resources.outputs.postgresServerFqdn
output postgresDatabaseName string = resources.outputs.postgresDatabaseName
output postgresDatabaseId string = resources.outputs.postgresDatabaseId
output acrName string = resources.outputs.acrName
output acrLoginServer string = resources.outputs.acrLoginServer
output userAssignedIdentityId string = resources.outputs.userAssignedIdentityId
output userAssignedIdentityClientId string = resources.outputs.userAssignedIdentityClientId
output userAssignedIdentityPrincipalId string = resources.outputs.userAssignedIdentityPrincipalId
output policyAssignmentName string = policyAssignmentName
