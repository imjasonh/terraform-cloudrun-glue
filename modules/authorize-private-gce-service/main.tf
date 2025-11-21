// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

terraform {
  required_providers {
    google = { source = "hashicorp/google" }
  }
}

// Look up the regional backend service by name and region
data "google_compute_region_backend_service" "backend" {
  project = var.project_id
  name    = "gce-svc-${var.name}-${var.region}"
  region  = var.region
}

// Grant IAP access to the service account
resource "google_iap_web_region_backend_service_iam_member" "authorize-calls" {
  project                    = var.project_id
  region                     = var.region
  web_region_backend_service = data.google_compute_region_backend_service.backend.name
  role                       = "roles/iap.httpsResourceAccessor"
  member                     = "serviceAccount:${var.service-account}"
}

// Look up the forwarding rule in the specified region
data "google_compute_forwarding_rule" "internal_alb" {
  depends_on = [google_iap_web_region_backend_service_iam_member.authorize-calls]

  project = var.project_id
  name    = "gce-svc-${var.name}-${var.region}"
  region  = var.region
}
