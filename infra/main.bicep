targetScope = 'subscription'

@description('The name of the resource group to create')
@minLength(1)
@maxLength(90)
param resourceGroupName string

@description('The location for all resources')
param location string

@description('The name of the AKS cluster')
@minLength(1)
@maxLength(63)
param aksClusterName string

@description('The name of the PostgreSQL Flexible Server')
@minLength(1)
@maxLength(63)
param postgresServerName string

@description('The name of the Redis Cache')
@minLength(1)
@maxLength(63)
param redisCacheName string

@description('PostgreSQL database name')
@minLength(1)
@maxLength(63)
param postgresDatabaseName string

@description('Azure AD Object ID of the user to set as PostgreSQL admin')
param azureADObjectId string

@description('Azure AD User Principal Name of the user to set as PostgreSQL admin')
param azureADUserPrincipalName string

@description('Name of the User Assigned Managed Identity for the application')
@minLength(1)
@maxLength(63)
param userAssignedIdentityName string

@description('Name of the Azure Container Registry')
@minLength(5)
@maxLength(50)
param acrName string


@description('Tags to apply to all resources')
param tags object

// Create the resource group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy resources to the new resource group
module resources 'resources.bicep' = {
  name: 'deploy-resources'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    aksClusterName: '${aksClusterName}-${uniqueString(rg.id)}'
    postgresServerName: '${postgresServerName}-${uniqueString(rg.id)}'
    redisCacheName: '${redisCacheName}-${uniqueString(rg.id)}'
    postgresDatabaseName: postgresDatabaseName
    azureADObjectId: azureADObjectId
    azureADUserPrincipalName: azureADUserPrincipalName
    userAssignedIdentityName: userAssignedIdentityName
    acrName: '${acrName}${uniqueString(rg.id)}'
    tags: tags
  }
}

// Outputs - Essential information for Spring PetClinic deployment
output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
output aksClusterName string = resources.outputs.aksClusterName
output aksClusterFqdn string = resources.outputs.aksClusterFqdn
output aksClusterId string = resources.outputs.aksClusterId
output postgresServerName string = resources.outputs.postgresServerName
output postgresServerFqdn string = resources.outputs.postgresServerFqdn
output postgresDatabaseName string = resources.outputs.postgresDatabaseName
output postgresDatabaseId string = resources.outputs.postgresDatabaseId
output redisCacheName string = resources.outputs.redisCacheName
output redisCacheHostName string = resources.outputs.redisCacheHostName
output redisCachePort string = resources.outputs.redisCachePort
output redisCacheSslPort string = resources.outputs.redisCacheSslPort
output redisCacheId string = resources.outputs.redisCacheId
output acrName string = resources.outputs.acrName
output acrLoginServer string = resources.outputs.acrLoginServer
output userAssignedIdentityId string = resources.outputs.userAssignedIdentityId
output userAssignedIdentityClientId string = resources.outputs.userAssignedIdentityClientId
output userAssignedIdentityPrincipalId string = resources.outputs.userAssignedIdentityPrincipalId
output redisAccessIdentityId string = resources.outputs.redisAccessIdentityId
output redisAccessIdentityClientId string = resources.outputs.redisAccessIdentityClientId
output redisAccessIdentityPrincipalId string = resources.outputs.redisAccessIdentityPrincipalId
