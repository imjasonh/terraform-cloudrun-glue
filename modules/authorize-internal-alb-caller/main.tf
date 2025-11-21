// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.79"
    }
  }
}

// Look up the backend service by name
data "google_compute_backend_service" "backend" {
  project = var.project_id
  name    = "gce-svc-${var.name}"
}

// Grant IAP access to the service account
resource "google_iap_web_backend_service_iam_member" "authorize-calls" {
  project             = var.project_id
  web_backend_service = data.google_compute_backend_service.backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "serviceAccount:${var.service_account}"
}

// Look up the forwarding rule in the specified region
data "google_compute_forwarding_rule" "internal_alb" {
  depends_on = [google_iap_web_backend_service_iam_member.authorize-calls]

  project = var.project_id
  name    = "gce-svc-${var.name}-${var.region}"
  region  = var.region
}
