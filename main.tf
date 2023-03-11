# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

#Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "myTFResourceGroup"
  location = "East US"
}

# Create a Virtual Network
resource "azurerm_virtual_network" "vnet" {
    name                = "myTFVnet"
    address_space       = ["10.0.1.0/24"]
    location            = "East US"
    resource_group_name = azurerm_resource_group.rg.name
}

# Create a Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "myTFSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                = "myTFPublicIP"
  location            = "East US"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "myTFNSG"
  location            = "East US"
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                      = "myNIC"
  location                  = "East US"
  resource_group_name       = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNICConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = "myTFVM"
  location              = "East US"
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = lookup(var.sku, var.location)
    version   = "latest"
  }

  os_profile {
    computer_name  = "myTFVM"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }


provisioner "remote-exec" {
  inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

  connection {
   host = "${azurerm_public_ip.publicip.ip_address}"
   type = "ssh"
   user = var.admin_username
   password = var.admin_password
  }
 }

provisioner "local-exec" {
  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook install-java.yml -i inventory.yml -e ansible_host=${azurerm_public_ip.publicip.ip_address} -e ansible_ssh_user='${var.admin_username}' -e ansible_ssh_pass='${var.admin_password}' -vv  && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook install-tomcat.yml -i inventory.yml -e ansible_host=${azurerm_public_ip.publicip.ip_address} -e ansible_ssh_user='${var.admin_username}' -e ansible_ssh_pass='${var.admin_password}' -vv"
    }

}
