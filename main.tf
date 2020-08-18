provider "azurerm" {
  version         = "2.18.0"

  features {}
}

locals {
      tags = {
        environment = "dev"
    }
    name = "prod-najim"

    

}

#oppretter resource group
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "${local.name}-rg"
    location = "North Europe"
    tags = local.tags

}
#Lager det virtuelle nettverket
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "${local.name}-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "North Europe"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
    tags = local.tags

}
#Oppretter subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.2.0/24"]
}
#Lager public ip adresse
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "qa-najim-ip"
    location                     = "North Europe"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "dev"
    }
}

#Oppretter nettverk sikkerhets gruppe med regler for å tillate SSH traffic i port 22
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "qa-najim-nsg"
    location            = "North Europe"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefixes    = ["37.191.239.220","84.210.156.116","37.191.172.135"]
        destination_address_prefix = "*"
    }

    tags = {
        environment = "dev"
    }
}



#Oppretter virtual network interface kort
resource "azurerm_network_interface" "myterraformnic" {
    name                        = "qa-myname-nic"
    location                    = "North Europe"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "dev"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "eksempel" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
#Lager storage for diagnostikk
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }
    
    byte_length = 8
}
#Oppretter storage
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "North Europe"
    account_replication_type    = "LRS"
    account_tier                = "Standard"

    tags = {
        environment = "dev"
    }
}

# Lager (og viser) en SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = "${tls_private_key.example_ssh.private_key_pem}" }

# Lager den virtuelle maskinen
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "myVMprod-najim-vm"
    location              = "North Europe"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    computer_name  = "myvm"
    admin_username = "azureuser"
    disable_password_authentication = true
        
    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "dev"
    }
}