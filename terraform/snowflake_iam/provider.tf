terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.34.0"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.18.0"
    }
  }
}

provider "google" {
  # Configuration options
  project = var.project_id
  region  = "africa-south1"
  zone    = "africa-south1-b"
}

provider "snowflake" {
  organization_name = var.org_name
  account_name      = var.account_name
  user              = var.username
  password          = var.password
  preview_features_enabled = [
    "snowflake_pipe_resource"
  ]
}