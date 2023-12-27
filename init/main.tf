terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.85.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "b0448874-98ba-4e20-be2d-b9629a3aca74"
  tenant_id = "b41b72d0-4e9f-4c26-8a69-f949f367c91d"
  client_id = "30316a8c-2e29-4f3d-b44e-ba156c4f005b"
  client_secret = "M9B8Q~vfpofsR2Q0~3dRnTpJLs4mfWpti.d4YaKY"
  features {}
}

resource "azurerm_resource_group" "resource_group" {
    name = "dn-resource-group"
    location = "East US 2"
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "dnstorageaccount"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"  
  tags = {
    environment = "staging"
  }
  depends_on = [ 
        azurerm_resource_group.resource_group 
    ]
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "blob"
  depends_on = [ azurerm_storage_account.storage_account ]
}

resource "azurerm_storage_blob" "maintf" {
  name                   = "main.tf"
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.storage_container.name
  type                   = "Block"
  source                 = "main.tf"
  depends_on = [ azurerm_storage_container.storage_container ]
}