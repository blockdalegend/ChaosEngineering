@description('The existing virtual machine resource you want to target in this experiment')
param targetName string

@description('Desired name for your Chaos Experiment')
param experimentName string = 'RotateCertificate'

@description('Desired region for the experiment, targets, and capabilities')
param location string = resourceGroup().location

// Define Chaos Studio experiment steps for a basic Virtual Machine Shutdown experiment
param experimentSteps array = [
  {
    name: 'Step1'
    branches: [
      {
        name: 'Branch1'
        actions: [
          {
            name: 'urn:csci:microsoft:keyvault:incrementCertificateVersion/1.0'
            type: 'discrete'
            duration: 'PT10M'
            parameters: [
              {
                key: 'certificateName'
                value: 'clustersslcert'
              }
            ]
            selectorId: 'Selector1'
          }
        ]
      }
    ]
  }
]

// Reference the existing Virtual Machine resource
resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: targetName
}

// Deploy the Chaos Studio target resource to the Virtual Machine
resource chaosTarget 'Microsoft.Chaos/targets@2022-10-01-preview' = {
  name: 'Microsoft-KeyVault'
  location: location
  scope: keyvault
  properties: {}

  // Define the capability -- in this case, VM Shutdown
  resource chaosCapability 'capabilities' = {
    name: 'UpdateCertificatePolicy-1.0'
  }
}

// Define the role definition for the Chaos experiment
resource chaosRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: keyvault
  // In this case, Virtual Machine Contributor role -- see https://learn.microsoft.com/azure/role-based-access-control/built-in-roles 
  name: '6f076d29-256e-4c7d-9549-ea4c38f1b32b'
}

// Define the role assignment for the Chaos experiment
resource chaosRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyvault.id, chaosExperiment.id, chaosRoleDefinition.id)
  scope: keyvault
  properties: {
    roleDefinitionId: chaosRoleDefinition.id
    principalId: chaosExperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deploy the Chaos Studio experiment resource
resource chaosExperiment 'Microsoft.Chaos/experiments@2022-10-01-preview' = {
  name: experimentName
  location: location // Doesn't need to be the same as the Targets & Capabilities location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    selectors: [
      {
        id: 'Selector1'
        type: 'List'
        targets: [
          {
            id: chaosTarget.id
            type: 'ChaosTarget'
          }
        ]
      }
    ]
    startOnCreation: false // Change this to true if you want to start the experiment on creation
    steps: experimentSteps
  }
}
