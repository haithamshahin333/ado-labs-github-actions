##################################################################################
# LOCALS
##################################################################################

locals {
  resource_group_name    = "${var.naming_prefix}-${random_integer.sa_num.result}"
  storage_account_name   = "${lower(var.naming_prefix)}${random_integer.sa_num.result}"
  service_principal_name = "${var.naming_prefix}-${random_integer.sa_num.result}"
  ssh_public_key         = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7iCN9Tc4m2PzfZbCy+v2SJStpf/lc9EloupG6IRFFIQ8tlUtZizQvvrHYThiuAgHBfBLgdPjGEvOtUYs8sjr3OAsByk+wBjPg14Tw37pKbMXdJBwKiW5Fw+/sVIsR8pyIBb84n0BFLi1W7IJJB9GK7faCVmZ7LDFGmXjgckWKQTnYgJvy133lfzBBR1w8qRpL/bpD6kU6mTv4yRGurPQQFKlfZo6497i9NYcOZdO+K3bn+yn/GvLqyhFbI4/JHnD3LkbTD/P3UMZtgj1vwmxWZcbaZBmD9AwzS5zdNdFYwfOh9poqPgtNfEFAnrk+pPHQrmMpZYPr05O0Dtj4XlT69dpNfPhic7G2qgOxIgJDokfaCE4sKwaDeUOPAQmh6ooAJNNaYTbe7ilKCQRKTJyWbM90rVAT7QDHyT84bT7Z9RREatXdIa9OBnqtpK9GLde0dOFskMkM4ub/8kwm4GMvcsk/4fUzCmz0yVWRFCODz5QAlN9sZPqwFQWuVxPoAkoSwNf6e7NbqWzPrVngX/HGTXVGj30NNDGygvC/nTmE7DjIbDP2TJDxRtfz8MOBpNzIQ0gr8lUc/plsahSmC/loBByQJnzgZc6u5NmOFqtHr0VoEIuY3ND/vuP4cS62fERph0xQzq62man6tKdQC5Vsqr8opRpCi6FCGHbNQM3Q0Q== hshahin@DESKTOP-631K2UD"
}

##################################################################################
# RESOURCES
##################################################################################

## AZURE AD SP ##

data "azurerm_subscription" "current" {}

data "azuread_client_config" "current" {}

resource "azuread_application" "gh_actions" {
  display_name = local.service_principal_name
  owners = [ data.azuread_client_config.current.object_id ]
}

resource "azuread_service_principal" "gh_actions" {
  application_id = azuread_application.gh_actions.application_id
  owners = [ data.azuread_client_config.current.object_id ]
}

resource "azuread_service_principal_password" "gh_actions" {
  service_principal_id = azuread_service_principal.gh_actions.object_id
}

resource "azurerm_role_assignment" "gh_actions" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gh_actions.id
}

# Azure Storage Account

resource "random_integer" "sa_num" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "setup" {
  name     = local.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.setup.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

resource "azurerm_storage_container" "ct" {
  name                 = "terraform-state"
  storage_account_name = azurerm_storage_account.sa.name

}

## GitHub secrets

resource "github_actions_secret" "actions_secret" {
  for_each = {
    STORAGE_ACCOUNT     = azurerm_storage_account.sa.name
    RESOURCE_GROUP      = azurerm_storage_account.sa.resource_group_name
    CONTAINER_NAME      = azurerm_storage_container.ct.name
    ARM_CLIENT_ID       = azuread_service_principal.gh_actions.application_id
    ARM_CLIENT_SECRET   = azuread_service_principal_password.gh_actions.value
    ARM_SUBSCRIPTION_ID = data.azurerm_subscription.current.subscription_id
    ARM_TENANT_ID       = data.azuread_client_config.current.tenant_id
    SSH_PUBLIC_KEY      = local.ssh_public_key
  }

  repository      = var.github_repository
  secret_name     = each.key
  plaintext_value = each.value
}