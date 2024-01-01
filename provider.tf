# Provider
provider "google" {
  project = "dataloop-409819"
  region  = "us-central1"
}

# Backend
terraform {
  backend "gcs" {
    bucket = "dataloop-tfstate"
    prefix = "terraform/state"
  }
}