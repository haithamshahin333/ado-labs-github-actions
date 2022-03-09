##################################################################################
# TERRAFORM CONFIG
##################################################################################
terraform {
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "~> 2.0"
        }
        
        random = {
        source = "hashicorp/random"
        version = "3.1.0"
        }
    }
    backend "azurerm" {
        key = "app.terraform.tfstate"
    }
}


##################################################################################
# PROVIDERS
##################################################################################

provider "azurerm" {
  features {}
}