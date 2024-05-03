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
  tenant_id = ""
  client_id = ""
  client_secret = ""
  features {}
}

resource "azurerm_resource_group" "resource_group" {
    name = "az-dn-group"
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

resource "azurerm_monitor_action_group" "monitor_action_group" {
  name                = "CriticalAlertsAction"
  short_name          = "p0action"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = azurerm_resource_group.resource_group.location
  depends_on = [ azurerm_storage_account.storage_account ]
}

resource "azurerm_consumption_budget_resource_group" "consumption_budget_resource_group" {
  name = "DnConsumptionResourceGroup"
  resource_group_id = azurerm_resource_group.resource_group.id

  amount = 10
  time_grain = "Monthly"

  time_period {
    start_date = "2024-01-01T00:00:00Z"
    end_date = "2024-02-01T00:00:00Z"
  }

  filter {
    dimension {
      name = "ResourceId"
      values = [
        azurerm_resource_group.resource_group.id
      ]
    }
  }
  notification {
    enabled        = true
    threshold      = 50.0
    operator       = "EqualTo"
    threshold_type = "Forecasted"

    contact_emails = [
      "foo@example.com",
      "bar@example.com",
    ]

    contact_groups = [
      azurerm_monitor_action_group.monitor_action_group.id
    ]

    contact_roles = [
      "Owner"
    ]
  }
  depends_on = [ azurerm_monitor_action_group.monitor_action_group ]
}


resource "azurerm_virtual_network" "appnetwork" {
  name                = "dn-network"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/23"]

  subnet {
    name           = "dn-subnet-default"
    address_prefix = "10.0.0.0/24"
  }

  subnet {
    name           = "dn-subnet-bastion"
    address_prefix = "10.0.1.0/26"    
  }

  subnet {
    name           = "dn-subnet-firewall"
    address_prefix = "10.0.1.64/26"    
  }
}