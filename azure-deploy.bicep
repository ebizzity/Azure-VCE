//declare variables
param vnetName string = 'embtxtdemo'
param VCEName string = 'VCE-Demo01'
param location string = 'eastus'
param pubIPName string = 'VCEDemo01-pip'
param pubInterfaceSubnetName string = 'Public'
param intInterfaceSubnetName string = 'Inside'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string 


// reference existing vnet
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

// reference existing subnets
resource pubSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: pubInterfaceSubnetName
  parent: vnet
}

resource intSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: intInterfaceSubnetName
  parent: vnet
}

// Create public IP 
resource publicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: pubIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Create public interface
resource publicInterface 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-pub'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'pub'
        properties: {
          subnet: {
            id: pubSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
  }
}


// Create internal interface
resource internalInterface 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-int'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'int'
        properties: {
          subnet: {
            id: intSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Create VCE VM and attach interfaces
resource VCEVM 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: VCEName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'vmware-inc'
        offer: 'sol-42222-bbj'
        sku: 'vmware_sdwan_501x'
        version: 'latest'
      }
      osDisk: {
        name: 'myOsDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: VCEName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: publicInterface.id
          properties: {
            primary: true
          }
        }
        {
          id: internalInterface.id
          properties: {
            primary: false
          }
        }
      ]
    }
  }
  plan: {
    name: 'vmware_sdwan_501x'
    publisher: 'vmware-inc'
    product: 'sol-42222-bbj'
  }
}
