//declare variables
param AllowSSHFromIP string = 'x.x.x.x'
param vcecount int = 2
param vnetName string = 'VNETName'
param VCEName string = 'VCE-Demo01'
param location string = 'eastus'
param pubIPName string = 'VCEDemo01-pip'
param pubInterfaceSubnetName string = 'Public'
param pubsubnetPrefix string = '10.220.0.0/28'
param intInterfaceSubnetName string = 'Inside'
param intsubnetPrefix string = '10.220.0.16/28'
param m365InterfaceSubnetName string = 'M365-Egress'
param m365subnetPrefix string = '10.220.0.32/28'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string 
param pipprefixLength int = 30

// reference existing vnet
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

// update existing subnet with NSG
resource pubSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: pubInterfaceSubnetName
  parent: vnet
  properties: {
    addressPrefix: pubsubnetPrefix
    networkSecurityGroup: {
      id: pubnsg.id
    }
}
}

// update existing subnet with NSG
resource intSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: intInterfaceSubnetName
  parent: vnet
  properties: {
    addressPrefix: intsubnetPrefix
    networkSecurityGroup: {
      id: intnsg.id
    }
}
}

// update existing subnet with NSG and NAT Gateway
resource m365Subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: m365InterfaceSubnetName
  parent: vnet
  properties: {
    addressPrefix: m365subnetPrefix
    networkSecurityGroup: {
      id: m365nsg.id
    }
    natGateway: {
      id: natGateway.id
    }
}
}



// Create public IP prefix
resource publicIPPrefix 'Microsoft.Network/publicIPPrefixes@2021-02-01' = {
  name: '${VCEName}-pipfx'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    prefixLength: pipprefixLength
  }
}

// Create Nat Gateway
resource natGateway 'Microsoft.Network/natGateways@2021-02-01' = {
  name: '${VCEName}-natgw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpPrefixes: [
      {
        id: publicIPPrefix.id
      }
    ]
    idleTimeoutInMinutes: 4

  }
}
      

// Create Network Security Group
resource pubnsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${VCEName}-pub-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-User'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: AllowSSHFromIP
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-VMWare-Multipath'
        properties: {
          priority: 1010
          protocol: 'UDP'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '2426'
        }
      }
    ]
  }
}



//Create Internal Subnet Network Security Group
resource intnsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${VCEName}-int-nsg'
  location: location
  properties: {
    securityRules: [
      
      
    ]
  }
}

//Create M365 Subnet Network Security Group
resource m365nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${VCEName}-m365-nsg'
  location: location
  properties: {
    securityRules: [
      
      
    ]
  }
}

// Build VCEs

// Create internal interface
resource internalInterface01 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-int-01'
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


// Create public IP 
resource publicIP01 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${pubIPName}-01'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}


// Create public interface
resource publicInterface01 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-pub-01'
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
            id: publicIP01.id
          }
        }
      }
    ]
  }
}


// Create M365 interface
resource m365Interface01 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-m365-01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'm365'
        properties: {
          subnet: {
            id: m365Subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Create VCE VM and attach interfaces
resource VCEVM01 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: '${VCEName}-01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS3_v2'
    }
    storageProfile: {
      imageReference: {
        publisher: 'vmware-inc'
        offer: 'sol-42222-bbj'
        sku: 'vmware_sdwan_501x'
        version: 'latest'
      }
      osDisk: {
        name: 'VCE-01-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: '${VCEName}-01'
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
          id: publicInterface01.id
          properties: {
            primary: true
          }
        }
        {
          id: internalInterface01.id
          properties: {
            primary: false
          }
        }
        {
          id: m365Interface01.id
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

// Create internal interface
resource internalInterface02 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-int-02'
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


// Create public IP 
resource publicIP02 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${pubIPName}-02'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}


// Create public interface
resource publicInterface02 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-pub-02'
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
            id: publicIP02.id
          }
        }
      }
    ]
  }
}


// Create M365 interface
resource m365Interface02 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${VCEName}-m365-02'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'm365'
        properties: {
          subnet: {
            id: m365Subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Create VCE VM and attach interfaces
resource VCEVM02 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: '${VCEName}-02'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS3_v2'
    }
    storageProfile: {
      imageReference: {
        publisher: 'vmware-inc'
        offer: 'sol-42222-bbj'
        sku: 'vmware_sdwan_501x'
        version: 'latest'
      }
      osDisk: {
        name: 'VCE-02-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: '${VCEName}-02'
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
          id: publicInterface02.id
          properties: {
            primary: true
          }
        }
        {
          id: internalInterface02.id
          properties: {
            primary: false
          }
        }
        {
          id: m365Interface02.id
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

//output network interface ip addresses
output VCE01publicIP string = publicIP01.properties.ipAddress
output VCE01publicInterface string = publicInterface01.properties.ipConfigurations[0].properties.privateIPAddress
output VCE01internalInterface string = internalInterface01.properties.ipConfigurations[0].properties.privateIPAddress
output VCE01m365Interface string = m365Interface01.properties.ipConfigurations[0].properties.privateIPAddress
output VCE02publicIP string = publicIP02.properties.ipAddress
output VCE02publicInterface string = publicInterface02.properties.ipConfigurations[0].properties.privateIPAddress
output VCE02internalInterface string = internalInterface02.properties.ipConfigurations[0].properties.privateIPAddress
output VCE02m365Interface string = m365Interface02.properties.ipConfigurations[0].properties.privateIPAddress
