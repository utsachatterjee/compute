terraform {
  required_version = ">= 1.2"
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {
  host = var.workspace_url
}