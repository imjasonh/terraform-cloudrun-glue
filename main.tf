terraform {
  required_providers {
    ko = { source = "ko-build/ko" }
  }
}

provider "ko" {
  repo = "gcr.io/${local.project_id}/${local.name}"
}

provider "google" {
  project = local.project_id
}

locals {
  name       = "example-gce-svc"
  project_id = "jason-chainguard"
  regions    = ["us-east1", "us-west1"]
}

module "networking" {
  source = "./modules/networking"

  name       = local.name
  project_id = local.project_id
  regions    = local.regions
}

resource "ko_build" "backend" {
  importpath = path.module
}

resource "google_service_account" "sa" {
  account_id = local.name
  project    = local.project_id
}

module "regional-gce-service" {
  source = "./modules/regional-gce-service"

  project_id = local.project_id
  name       = local.name
  regions    = module.networking.regional-networks

  instance_count  = 2
  machine_type    = "e2-medium"
  service_account = google_service_account.sa.email
  disk_size_gb    = 20

  iap = {
    oauth2_client_id     = "example-client-id.apps.googleusercontent.com"
    oauth2_client_secret = "example-secret"
  }

  container = {
    image = ko_build.backend.image_ref
  }
}

resource "google_service_account" "frontend" {
  account_id = "${local.name}-frontend"
  project    = local.project_id
}

resource "ko_build" "frontend" {
  importpath = "${path.module}/frontend"
}

module "regional-go-service" {
  source = "./modules/regional-go-service"

  name            = "${local.name}-frontend"
  project_id      = local.project_id
  regions         = module.networking.regional-networks
  service_account = google_service_account.frontend.email
  ingress         = "INGRESS_TRAFFIC_ALL"
  containers = {
    "frontend" = {
      source = {
        working_dir = "${path.module}/frontend"
        importpath  = "./"
      }
      ports = [{ container_port = 8080 }]
      regional-env = [{
        name = "BACKEND_ADDRESS", value = { for k, v in module.frontend-calls-backend : k => "http://${v.ip_address}" }
      }]
    }
  }
  notification_channels = []
}

module "frontend-calls-backend" {
  depends_on = [module.regional-gce-service]
  for_each   = module.networking.regional-networks
  source     = "./modules/authorize-private-gce-service"

  project_id      = local.project_id
  region          = each.key
  name            = local.name
  service-account = google_service_account.frontend.email
}

output "backends" {
  value = { for k, v in module.frontend-calls-backend : k => v.ip_address }
}

output "frontends" {
  value = module.regional-go-service.uris
}
