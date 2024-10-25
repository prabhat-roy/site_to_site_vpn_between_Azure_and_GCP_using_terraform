terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}

provider "azurerm" {
  subscription_id = var.sub_id
  features {}
}

provider "google" {
  project     = var.project_id
  region      = var.gcp_region
  credentials = var.cred
}
