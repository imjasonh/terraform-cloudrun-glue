// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.79"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.79"
    }
  }
}

locals {
  default_labels = {
    basename(abspath(path.module)) = var.prefix
    terraform-module               = basename(abspath(path.module))
  }

  squad_label = var.squad != "" ? {
    squad = var.squad
    team  = var.squad
  } : {}

  merged_labels = merge(local.default_labels, local.squad_label, var.labels)
}

// Container manifest for the GCE instance template
// This configures Container-Optimized OS to run the specified Docker image
locals {
  container_manifest = <<-EOT
    spec:
      containers:
      - name: ${var.prefix}
        image: ${var.container_image}
        stdin: false
        tty: false
      restartPolicy: Always
  EOT
}

// Instance template for Container-Optimized OS VMs
resource "google_compute_instance_template" "container_vm" {
  name_prefix  = "${var.prefix}-"
  project      = var.project_id
  machine_type = var.machine_type
  tags         = ["${var.prefix}-backend"]

  labels = local.merged_labels

  disk {
    source_image = "cos-cloud/cos-stable"
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size_gb
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnetwork_self_link
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
    gce-container-declaration = local.container_manifest
  }

  lifecycle {
    create_before_destroy = true
  }
}

// Regional instance group managers (MIGs) for each region
resource "google_compute_region_instance_group_manager" "mig" {
  for_each = toset(var.regions)

  name    = "${var.prefix}-${each.key}"
  project = var.project_id
  region  = each.key

  base_instance_name = "${var.prefix}-${each.key}"
  target_size        = var.instance_count

  version {
    instance_template = google_compute_instance_template.container_vm.id
  }

  named_port {
    name = "http-8080"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http_8080.id
    initial_delay_sec = 300
  }
}

// Health check for the backend service
resource "google_compute_health_check" "http_8080" {
  name    = "${var.prefix}-http-8080"
  project = var.project_id

  http_health_check {
    port         = 8080
    request_path = "/"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

// Backend service with IAP and logging enabled
resource "google_compute_backend_service" "internal_backend" {
  name                  = "${var.prefix}-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http-8080"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.http_8080.id]

  // Add backends for each regional MIG
  dynamic "backend" {
    for_each = toset(var.regions)
    content {
      group           = google_compute_region_instance_group_manager.mig[backend.key].instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  }

  // Enable IAP
  iap {
    enabled              = true
    oauth2_client_id     = var.iap_oauth_client_id
    oauth2_client_secret = var.iap_oauth_client_secret
  }

  // Enable request logging for observability
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

// IAM bindings for IAP access
resource "google_iap_web_backend_service_iam_member" "access_grant" {
  for_each = toset(var.authorized_service_accounts)

  project             = var.project_id
  web_backend_service = google_compute_backend_service.internal_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "serviceAccount:${each.value}"
}

// URL map that routes all traffic to the backend service
resource "google_compute_url_map" "internal_urlmap" {
  name            = "${var.prefix}-urlmap"
  project         = var.project_id
  default_service = google_compute_backend_service.internal_backend.id
}

// HTTP proxy for the URL map
resource "google_compute_target_http_proxy" "internal_proxy" {
  name    = "${var.prefix}-proxy"
  project = var.project_id
  url_map = google_compute_url_map.internal_urlmap.id
}

// Internal forwarding rule (Load Balancer frontend)
resource "google_compute_forwarding_rule" "internal_frontend" {
  name                  = "${var.prefix}-frontend"
  project               = var.project_id
  region                = var.lb_frontend_region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.internal_proxy.id
  network               = var.network_self_link
  subnetwork            = var.lb_proxy_subnet_self_link
  allow_global_access   = true

  labels = local.merged_labels
}

// Firewall rule to allow health check and proxy traffic
resource "google_compute_firewall" "allow_health_check_and_proxy" {
  name    = "${var.prefix}-allow-health-proxy"
  project = var.project_id
  network = var.network_self_link

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [
    "130.211.0.0/22", // Google Cloud health check IPs
    "35.191.0.0/16",  // Google Cloud proxy IPs
  ]

  target_tags = ["${var.prefix}-backend"]
}
