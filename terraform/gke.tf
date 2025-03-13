# Create the K8s Cluster
resource "google_container_cluster" "cluster" {
  project  = var.project_id
  name     = var.gke_cluster["name"]
  location = var.region
  node_locations           = local.formatted_zones
  network                  = google_compute_network.network.name
  subnetwork               = google_compute_subnetwork.subnet.name
  min_master_version       = var.gke_cluster["kube_version"]
  remove_default_node_pool = true
  initial_node_count       = "1"
  resource_labels     = merge(var.labels, var.gke_labels)
  deletion_protection = false
  datapath_provider   = "ADVANCED_DATAPATH"

  dns_config {
    cluster_dns       = "CLOUD_DNS"
    cluster_dns_scope = "CLUSTER_SCOPE"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.subnet.secondary_ip_range.0.range_name
    services_secondary_range_name = google_compute_subnetwork.subnet.secondary_ip_range.1.range_name
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  addons_config {
    dns_cache_config {
      enabled = true
    }

    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [google_compute_network.network]
}

# Create the K8s node pool
resource "google_container_node_pool" "demo_pool" {
  project  = var.project_id
  name     = var.node_pool["name"]
  location = var.region
  cluster  = google_container_cluster.cluster.name

  autoscaling {
    min_node_count = var.gke_cluster["standard_machine_min_nodes"]
    max_node_count = var.gke_cluster["standard_machine_max_nodes"]
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    machine_type = var.node_pool["machine_type"]
    tags         = ["um-cluster", "standard", "gke-shared-node"]
    labels = {
      app-type = "demo"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# Create K8s namespaces
resource "kubernetes_namespace" "cert-manager-ns" {
  metadata {
    name = "cert-manager"
  }

  depends_on = [google_container_cluster.cluster]
}

resource "kubernetes_namespace" "monitoring-ns" {
  metadata {
    name = "monitoring"
  }
  
  depends_on = [google_container_cluster.cluster]
}

resource "kubernetes_namespace" "services-ns" {
  metadata {
    name = "services"
  }
  
  depends_on = [google_container_cluster.cluster]
}
######################

# Create the cert-manager with helm with CustomResourceDefinitions enabled and annotate the service
# Default values at https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/values.yaml
resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert-manager-ns.metadata.0.name
  version    = var.cert_manager_version

  set {
    name  = "installCRDs"
    value = true
  }
  
  depends_on = [kubernetes_namespace.cert-manager-ns]
}

# Deploy prometheus with helm
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring-ns.metadata.0.name
  version    = var.prometheus_version
  
  depends_on = [kubernetes_namespace.monitoring-ns]
}

# Deploy loki and grafana with helm
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring-ns.metadata.0.name
  version    = var.loki_version
  values     = [file("./conf/loki-stack-values.yaml")]
  
  depends_on = [kubernetes_namespace.monitoring-ns]
}
# kubectl get secret loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Kubernetes service account to services namespace
resource "kubernetes_service_account" "sa_services_ns" {
  metadata {
    name      = "${var.app_name}-sa"
    namespace = kubernetes_namespace.services-ns.metadata.0.name
    annotations = {
      "iam.gke.io/gcp-service-account" = "${google_service_account.gke_workload.account_id}@${var.project_id}.iam.gserviceaccount.com"
    }
  }
  
  depends_on = [kubernetes_namespace.services-ns]
}


