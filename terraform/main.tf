# main.tf

provider "google" {
  credentials = file("/Users/nadeemhaq/.config/gcloud/dataloop-409819-7c48fbb767f1.json")
  project     = "dataloop-409819"
  region      = "us-central1"
}

# Create VPC
resource "google_compute_network" "my_vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = false
}

# Create Subnet
resource "google_compute_subnetwork" "my_subnet" {
  name          = "my-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.my_vpc.self_link
  region        = "us-central1"
}

resource "google_container_cluster" "my_cluster" {
  name               = "my-gke-cluster"
  location           = "us-central1"
  network    = google_compute_network.my_vpc.self_link
  subnetwork = google_compute_subnetwork.my_subnet.self_link

  node_pool {
    name       = "default-pool"
    initial_node_count = 1
    autoscaling {
      min_node_count = 1
      max_node_count = 2
    }
  }
}

/*data "google_container_cluster" "my_cluster_data" {
  name     = google_container_cluster.my_cluster.name
  location = google_container_cluster.my_cluster.location
}*/

output "cluster_endpoint" {
  value       = google_container_cluster.my_cluster.endpoint
  description = "The endpoint of the GKE cluster"
}


# Execute kubectl command to fetch kubeconfig
/*data "external" "get_kubeconfig" {
  program = ["sh", "-c", "gcloud auth activate-service-account --key-file=/Users/nadeemhaq/.config/gcloud/dataloop-409819-7c48fbb767f1.json && gcloud container clusters get-credentials my-gke-cluster --region us-central1 --project dataloop-409819 && kubectl config view --raw --minify --flatten"]
}

output "kubeconfig" {
  value       = data.external.get_kubeconfig.result["kubeconfig"]
  description = "The kubeconfig for connecting to the GKE cluster"
}*/

# Retrieve an access token as the Terraform runner
data "google_client_config" "provider" {}

data "google_container_cluster" "my_cluster" {
  name     = "my-gke-cluster"
  location = "us-central1"
}

# main.tf

/*provider "kubernetes" {
  host                   = "https://${google_container_cluster.my_cluster.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.provider.access_token
}*/

resource "kubernetes_namespace" "grafana" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name = "grafana"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          image = "grafana/grafana:latest"
          name = "grafana"

          port {
            container_port = 3000
          }
        }
      }
    }

    replicas = 1
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name = "grafana"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      name = "http"
      port = 80
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}



resource "kubernetes_namespace" "nginx_namespace" {
  metadata {
    name = "services"
  }
}

resource "kubernetes_deployment" "nginx_deployment" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.nginx_namespace.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx"
    namespace = kubernetes_namespace.nginx_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      name = "http"
      port = 80
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "nginx_hpa" {
  metadata {
    name      = "nginx-hpa"
    namespace = kubernetes_namespace.nginx_namespace.metadata[0].name
  }

  spec {
    scale_target_ref {
      kind = "Deployment"
      name = kubernetes_deployment.nginx_deployment.metadata[0].name
    }

    min_replicas = 1
    max_replicas = 2

    metric {   
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type = "Utilization"
          average_utilization = "80"
        }
      }
    }
  }
}
