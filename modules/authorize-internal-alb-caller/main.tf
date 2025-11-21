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

resource "google_iap_web_backend_service_iam_member" "authorize-calls" {
  project             = var.project_id
  web_backend_service = var.backend_service_name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "serviceAccount:${var.service_account}"
}

data "google_compute_forwarding_rule" "internal_alb" {
  depends_on = [google_iap_web_backend_service_iam_member.authorize-calls]

  project = var.project_id
  name    = var.forwarding_rule_name
  region  = var.region
}
