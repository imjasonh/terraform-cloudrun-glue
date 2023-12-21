// Create a dedicated identity as which to run the broker ingress service
// (and authorize it's actions)
resource "google_service_account" "this" {
  project = var.project_id

  account_id   = var.name
  display_name = "Broker Ingress"
  description  = "A dedicated identity for the ${var.name} broker ingress to operate as."
}

// Authorize the ingress identity to publish events to each of
// the regional broker topics.
// NOTE: we use binding vs. member because we do not expect anything
// to publish to this topic other than the ingress service.
resource "google_pubsub_topic_iam_binding" "ingress-publishes-events" {
  for_each = var.regions

  project = var.project_id
  topic   = google_pubsub_topic.this[each.key].name
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${google_service_account.this.email}"]
}

// Build the ingress image using our minimal hardened base image.
resource "ko_build" "this" {
  base_image  = "cgr.dev/chainguard/static:latest-glibc"
  importpath  = "./cmd/ingress"
  working_dir = path.module
}

// Sign the image, assuming a keyless signing identity is available.
resource "cosign_sign" "this" {
  image = ko_build.this.image_ref

  # Only keep the latest signature.
  conflict = "REPLACE"
}

resource "google_cloud_run_v2_service" "this" {
  for_each = var.regions

  // Explicitly wait for the iam binding before provisioning the service,
  // since the service functionally depends on being able to publish events
  // to the topic.  In practice, GCP IAM is "eventually consistent" and there
  // will still invariably be some latency after even the service is created
  // where publishing may fail.
  depends_on = [google_pubsub_topic_iam_binding.ingress-publishes-events]

  project  = var.project_id
  name     = var.name
  location = each.key

  // The ingress service is an internal service, and so it should only
  // be exposed to the internal network.
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  launch_stage = "BETA" // Needed for vpc_access below

  template {
    vpc_access {
      network_interfaces {
        network    = each.value.network
        subnetwork = each.value.subnet
      }
      egress = "ALL_TRAFFIC" // This should not egress
    }

    service_account = google_service_account.this.email
    containers {
      image = cosign_sign.this.signed_ref

      env {
        name  = "PUBSUB_TOPIC"
        value = google_pubsub_topic.this[each.key].name
      }
    }
  }
}

module "topic" {
  source       = "../dashboard/sections/topic"
  title        = "Broker Events"
  topic_prefix = var.name
}

module "logs" {
  source = "../dashboard/sections/logs"
  title  = "Service Logs"
  filter = ["resource.type=\"cloud_run_revision\""]
}

module "http" {
  source = "../dashboard/sections/http"
  title  = "HTTP"
  filter = ["resource.type=\"cloud_run_revision\""]
}

module "resources" {
  source = "../dashboard/sections/resources"
  title  = "Resources"
  filter = ["resource.type=\"cloud_run_revision\""]
}

module "width" { source = "../dashboard/sections/width" }

module "layout" {
  source = "../dashboard/sections/layout"
  sections = [
    module.topic.section,
    module.logs.section,
    module.http.section,
    module.resources.section,
  ]
}

resource "google_monitoring_dashboard" "dashboard" {
  dashboard_json = jsonencode({
    displayName = "Cloud Events Broker Ingress: ${var.name}"
    labels = {
      "service" : ""
      "eventing" : ""
    }
    dashboardFilters = [{
      filterType  = "RESOURCE_LABEL"
      stringValue = var.name
      labelKey    = "service_name"
    }]

    // https://cloud.google.com/monitoring/api/ref_v3/rest/v1/projects.dashboards#mosaiclayout
    mosaicLayout = {
      columns = module.width.size
      tiles   = module.layout.tiles,
    }
  })
}
