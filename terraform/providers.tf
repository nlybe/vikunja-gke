terraform {
  required_providers {
    google = {
      source  = "registry.terraform.io/hashicorp/google"
      version = ">= 6.24.0"
    }

    google-beta = {
      source  = "registry.terraform.io/hashicorp/google-beta"
      version = ">= 6.24.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_project" "project" {
  project_id = var.project_id
}

# Retrieve an access token as the Terraform runner
data "google_client_config" "provider" {}

data "google_container_cluster" "gke-cluster" {
  depends_on = [google_container_cluster.cluster]
  name       = google_container_cluster.cluster.name
  project    = var.project_id
  location   = var.region
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.gke-cluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.gke-cluster.master_auth[0].cluster_ca_certificate,
  )
}

# Same parameters as kubernetes provider
provider "kubectl" {
  load_config_file       = false
  host                   = "https://${data.google_container_cluster.gke-cluster.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke-cluster.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.gke-cluster.endpoint}"
    token                  = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.gke-cluster.master_auth.0.cluster_ca_certificate)
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
