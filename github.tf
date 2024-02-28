// Testing GitHub API rate limit metrics

module "test-github-network" {
  source = "chainguard-dev/common/infra//modules/networking"

  name          = "test-github"
  project_id    = local.project
  regions       = ["us-east1"]
  netnum_offset = 1
}

resource "google_service_account" "service" {
  account_id   = "test-github"
  display_name = "Test SA"
}

module "this" {
  source     = "./modules/regional-go-service"
  project_id = "jason-chainguard"
  name       = "test-github"
  regions    = module.test-github-network.regional-networks

  ingress         = "INGRESS_TRAFFIC_ALL"
  egress          = "PRIVATE_RANGES_ONLY"
  service_account = google_service_account.service.email
  containers = {
    "svc" = {
      source = {
        working_dir = path.module
        importpath  = "./test"
      }
      ports = [{ container_port = 8080 }]
    }
  }

  notification_channels = []
}

module "width" { source = "./modules/dashboard/sections/width" }

module "github" {
  source        = "./modules/dashboard/sections/github"
  title         = "GitHub API"
  filter        = ["resource.type=\"cloud_run_revision\""]
  cloudrun_name = "test-github"
}

module "layout" {
  source = "./modules/dashboard/sections/layout"
  sections = [
    module.github.section,
  ]
}

resource "google_monitoring_dashboard" "dashboard" {
  dashboard_json = jsonencode({
    displayName = "Testing GitHub API metrics"
    labels = {
      "test" : ""
    }
    dashboardFilters = [{
      filterType  = "RESOURCE_LABEL"
      stringValue = "test-github"
      labelKey    = "service_name"
    }]

    mosaicLayout = {
      columns = module.width.size
      tiles   = module.layout.tiles,
    }
  })
}
