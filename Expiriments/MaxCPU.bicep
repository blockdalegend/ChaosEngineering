@description('The VMSS you want to target')
param targetName string

@description('Name of expiriment')
param experimentName string

param experimentSteps array = [
  {
    name: 'MaxOutCPU'
    branches: [
      {
        name: 'Branch1'
        actions: [
          {
            name: 'urn:csci:microsoft:agent:cpuPressure/1.0'
            type: 'continuous'
            duration: 'PT10M'
            parameters: [
              {
                key: 'pressureLevel'
                value: '95'
              }
              {
                key: 'virtualMachineScaleSetInstances'
                value: '[0,1,2,4,5]'
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
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-07-01' existing = {
  name: targetName
}

resource chaosTarget 'Microsoft.Chaos/targets@2022-10-01-preview' = {
  name: 'Microsoft-VirtualMachineScaleSets'
  location: resourceGroup().location
  scope: vmss
  properties: {}

  resource chaosCapability 'capabilities' = {
    name: 'CPUPressure-1.0'
  }
}

// Define the role definition for the Chaos experiment
resource chaosRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: vmss
  // In this case, Virtual Machine Contributor role -- see https://learn.microsoft.com/azure/role-based-access-control/built-in-roles 
  name: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
}

resource chaosRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(vmss.id, chaosExperiment.id, chaosRoleDefinition.id)
  scope: vmss
  properties: {
    roleDefinitionId: chaosRoleDefinition.id
    principalId: chaosExperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource chaosExperiment 'Microsoft.Chaos/experiments@2022-10-01-preview' = {
  name: experimentName
  location: resourceGroup().location // Doesn't need to be the same as the Targets & Capabilities location
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
