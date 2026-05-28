terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.34.0"
    }
  }
}

provider "google" {
  # Configuration options
  project = "project-ef0bfd1c-1d93-4d94-a0c"
  region  = "africa-south1"
  zone    = "africa-south1-b"
}