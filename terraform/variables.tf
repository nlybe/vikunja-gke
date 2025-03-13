variable "project_id" {
  type        = string
  description = "The name of the project used on GCP"
}

variable "region" {
  type        = string
  description = "The name of region used on GCP"
}

variable "zone" {
  type        = string
  description = "The name of main zone used on GCP"
  default     = "europe-west1-d"
}

variable "availability_zones" {
  type        = string
  description = "List of zone used on GCP"
}

variable "env_name" {
  type        = string
  description = "The environment name"
}

variable "labels" {
  type        = map(any)
  description = "General purpose labels"
  default = {
    env = "develop"
  }
}

variable "app_name" {
  type        = string
  description = "The application name"
}

######### GKE config
variable "gke_cluster" {
  type = map(any)
}

variable "gke_labels" {
  type        = map(any)
  description = "General purpose labels"
}

variable "node_pool" {
  type = map(any)
}
######### GKE config


######### Helm config
variable "cert_manager_version" {
  type        = string
  description = "Version of cert-manager helm chart"
  default     = "v1.17.1"
}

variable "prometheus_version" {
  type        = string
  description = "Version of prometheus helm chart"
  default     = "27.5.1"
}

variable "grafana_version" {
  type        = string
  description = "Version of grafana helm chart"
  default     = "8.10.3"
}

variable "loki_version" {
  type        = string
  description = "Version of loki helm chart"
  default     = "2.10.2"
} 
######### Helm config


######### Cloudflare config
variable "cloudflare_api_token" {
  type        = string
  description = "The Cloudflare api token terraform access"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Zone ID on Cloudflare"
}

variable "cf_app_dns_record" {
  type        = string
  description = "The DNS A record for the vikunja app"
}
######### Cloudflare config