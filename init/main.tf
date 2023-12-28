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

resource "azurerm_monitor_action_group" "monitor_action_group" {
  name                = "CriticalAlertsAction"
  short_name          = "p0action"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = azurerm_resource_group.resource_group.location
  depends_on = [ azurerm_storage_account.storage_account ]

  arm_role_receiver {
    name                    = "armroleaction"
    role_id                 = "de139f84-1756-47ae-9be6-808fbbe84772"
    use_common_alert_schema = true
  }
}

resource "azurerm_consumption_budget_resource_group" "consumption_budget_resource_group" {
  name = "DnConsumptionResourceGroup"
  resource_group_id = azurerm_resource_group.resource_group.id

  amount = 10
  time_grain = "Monthly"

  time_period {
    start_date = "2023-12-01T00:00:00Z"
    end_date = "2024-01-28T00:00:00Z"
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