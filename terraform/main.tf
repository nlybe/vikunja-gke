resource "google_compute_network" "network" {
  project                 = var.project_id
  name                    = "${var.env_name}-vpc"
  description             = "Network for the ${var.gke_cluster["name"]} cluster"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  project       = var.project_id
  name          = "${var.env_name}-sub"
  region        = var.region
  ip_cidr_range = "10.180.0.0/20"
  network       = google_compute_network.network.self_link

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.200.0.0/20"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.220.0.0/20"
  }
}

# IP address to be used by ingress of application
resource "google_compute_global_address" "app_ip" {
  project = var.project_id
  name    = "${var.app_name}-ip"
}

# storage bucket to be used by application as shared file storage
resource "google_storage_bucket" "app_bucket" {
  name          = "${var.app_name}-bucket-${var.env_name}"
  location      = var.region
  storage_class = "STANDARD"
}

# provide access to app storage bucket
resource "google_storage_bucket_iam_binding" "app_bucket_iam_binding" {
  depends_on = [google_service_account.gke_workload]
  bucket = google_storage_bucket.app_bucket.name
  role = "roles/storage.objectUser"
  members = [
    "serviceAccount:gke-workload-demo@${var.project_id}.iam.gserviceaccount.com",
  ]
}

resource "google_service_account" "gke_workload" {
  project      = var.project_id
  account_id   = "gke-workload-demo"
  display_name = "gke-workload-demo"
  description  = "GKE workload demo sa"
}

resource "google_service_account_iam_binding" "gke_workload_accessor_iam_binding" {
  service_account_id = google_service_account.gke_workload.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[services/${var.app_name}-sa]"
  ]
}

resource "cloudflare_record" "cf_nereus_ui_app_dns_record" {
  zone_id = var.cloudflare_zone_id
  name    = var.cf_app_dns_record
  content = google_compute_global_address.app_ip.address
  type    = "A"
  proxied = false

  depends_on = [google_compute_global_address.app_ip]
}

# "serviceAccount:${var.project_id}.svc.id.goog[services/${kubernetes_service_account.sa_services_ns.name}]"