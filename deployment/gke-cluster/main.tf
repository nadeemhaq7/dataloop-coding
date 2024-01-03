# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "google-beta" {
  project = "dataloop-409819"
  region  = "us-central1"
  zone = "us-central1-a"
}

# This is used to set local variable google_zone.
# This can be replaced with a statically-configured zone, if preferred.


resource "google_container_cluster" "default" {
  provider = google-beta
  project = "dataloop-409819"
  name               = var.cluster_name
  location           = "us-central1-a"
  initial_node_count = var.workers_count
  min_master_version = "1.27"
  # node version must match master version
  # https://www.terraform.io/docs/providers/google/r/container_cluster.html#node_version
  node_version = "1.27"
  

  release_channel {
    channel = "RAPID"
  }

  node_config {
    machine_type = "e2-small"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  identity_service_config {
    enabled = var.idp_enabled
  }

  deletion_protection = false
}
