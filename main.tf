terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.26.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "000000-000000-000000-0000000-00000"
  client_id       = "000000-000000-000000-0000000-00000"
  client_secret   = "hBw8Q~EMmeX6H~FzfJHR0jhsdvfksujbkrgufj"
  tenant_id       = "000000-000000-000000-0000000-00000"
  features {}
}

//resource group0000000000000000000000000000000000000000000000000000000000000

locals {
  resource_group = "test-tfrg"
  location       = "East US"
}


resource "azurerm_resource_group" "test-rg" {
  name     = local.resource_group
  location = local.location
}

//storage account00000000000000000000000000000000000000000000000000000000

variable "storage_account_name" {
  type    = string
  description="Enter the storage account name" 
}

resource "azurerm_storage_account" "tf-store" {
  name                          = var.storage_account_name
  resource_group_name           = local.resource_group
  location                      = local.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true

  depends_on = [azurerm_resource_group.test-rg]
}

resource "azurerm_storage_container" "tf-contain" {
  name                  = "tf-contain"
  storage_account_id    = azurerm_storage_account.tf-store.id
  container_access_type = "blob"
  depends_on = [
    azurerm_storage_account.tf-store
  ]
}

resource "azurerm_storage_blob" "sample" {
  name                   = "sample.txt"
  storage_account_name   = var.storage_account_name
  storage_container_name = "tf-contain"
  type                   = "Block"
  source                 = "sample.txt"
  depends_on             = [azurerm_storage_container.tf-contain]
}

//virtual machine iis server install00000000000000000000000000000000000000000000000000

resource "azurerm_storage_blob" "IIS_config" {
  name                   = "IIS_Config.ps1"
  storage_account_name   = var.storage_account_name
  storage_container_name = "tf-contain"
  type                   = "Block"
  source                 = "IIS_Config.ps1"
  depends_on             = [azurerm_storage_container.tf-contain]
}

resource "azurerm_virtual_machine_extension" "vm_extension" {
  name                       = "appvm-extension"
  virtual_machine_id         = azurerm_windows_virtual_machine.tf-vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true
  depends_on = [
    azurerm_storage_blob.IIS_config,
    azurerm_resource_group.test-rg
  ]
  settings = <<SETTINGS
    {
      "fileUris": ["https://${azurerm_storage_account.tf-store.name}.blob.core.windows.net/${azurerm_storage_container.tf-contain.name}/IIS_Config.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1" 
    }
SETTINGS

}

// virtual network part 88888888888888888888888888888888888888888888888888888888888888888888888888888888

variable "vitual_network_name" {
  type    = string
  default = "tf-vnet"
}


resource "azurerm_virtual_network" "tf-vnet" {
  name                = var.vitual_network_name
  location            = local.location
  resource_group_name = azurerm_resource_group.test-rg.name
  address_space       = ["10.0.0.0/16"]

  depends_on = [azurerm_resource_group.test-rg]
}

// adding subnet 8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

resource "azurerm_subnet" "tf-subnet" {
  name                 = "my-tf-subnet"
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.tf-vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [azurerm_virtual_network.tf-vnet]
}
//network interface 99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999

resource "azurerm_network_interface" "tf-nic" {
  name                = "tf-nic"
  location            = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tf-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf-pip.id
  }
  depends_on = [
    azurerm_virtual_network.tf-vnet,
    azurerm_public_ip.tf-pip,
  ]
}

//windows virtual machine 0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

resource "azurerm_linux_virtual_machine" "t-vm" {
  name                = "t-vm"
  resource_group_name = local.resource_group
  location            = local.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  admin_password = "Admin@123456789"
  disable_password_authentication = false  
  custom_data = data.template_cloudinit_config.linuxconfig.rendered
  network_interface_ids = [
    azurerm_network_interface.tf-nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.tf-nic,
  ]
}

// public ip 9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999

resource "azurerm_public_ip" "tf-pip" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = local.resource_group
  location            = local.location
  allocation_method   = "Static"

  depends_on = [azurerm_resource_group.test-rg]
}

# //nsg rules create 0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = local.location
  resource_group_name = local.resource_group

  # We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # We are creating a rule to allow traffic on port 3389
  security_rule {
    name                       = "Allow_SSH"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.test-rg]
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.tf-subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg,
    azurerm_resource_group.test-rg
  ]
}


