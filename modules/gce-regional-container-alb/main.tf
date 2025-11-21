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
  # Extract the primary port (first port in the list, defaults to 8080)
  primary_port = length(var.container.ports) > 0 ? var.container.ports[0].container_port : 8080
  port_name    = length(var.container.ports) > 0 ? var.container.ports[0].name : "http1"

  # Build environment variables section if provided
  # Using yamlencode to properly escape special characters
  env_vars = length(var.container.env) > 0 ? [
    for env in var.container.env : {
      name  = env.name
      value = env.value
    }
  ] : []

  # Build ports section for the container
  container_ports = length(var.container.ports) > 0 ? [
    for port in var.container.ports : {
      containerPort = port.container_port
    }
  ] : null

  # Build container spec as a structured object for proper YAML encoding
  container_spec = {
    spec = {
      containers = [{
        name    = var.prefix
        image   = var.container.image
        command = length(var.container.args) > 0 ? var.container.args : null
        env     = length(local.env_vars) > 0 ? local.env_vars : null
        ports   = local.container_ports
        stdin   = false
        tty     = false
      }]
      restartPolicy = "Always"
    }
  }

  # Use yamlencode to safely generate the manifest
  container_manifest = yamlencode(local.container_spec)
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
    name = "http-${local.primary_port}"
    port = local.primary_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http_8080.id
    initial_delay_sec = 300
  }
}

// Health check for the backend service
resource "google_compute_health_check" "http_8080" {
  name    = "${var.prefix}-http-${local.primary_port}"
  project = var.project_id

  http_health_check {
    port         = local.primary_port
    request_path = "/"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

// Create IAP brand and OAuth client if not provided
data "google_project" "project" {
  project_id = var.project_id
}

// Create IAP brand if IAP config not provided
// Note: Only one brand can exist per project. If a brand already exists,
// you must provide the iap variable with existing OAuth credentials.
// The IAP brand/client APIs are deprecated and will be shut down March 19, 2026.
resource "google_iap_brand" "project_brand" {
  count             = var.iap == null ? 1 : 0
  support_email     = var.iap_support_email
  application_title = "${var.prefix} IAP"
  project           = data.google_project.project.number
}

// Create OAuth client for IAP if IAP config not provided
resource "google_iap_client" "oauth_client" {
  count        = var.iap == null ? 1 : 0
  display_name = "${var.prefix}-iap-client"
  brand        = google_iap_brand.project_brand[0].name
}

locals {
  # Use provided IAP config or created OAuth client
  iap_client_id     = var.iap != null ? var.iap.oauth2_client_id : try(google_iap_client.oauth_client[0].client_id, "")
  iap_client_secret = var.iap != null ? var.iap.oauth2_client_secret : try(google_iap_client.oauth_client[0].secret, "")
}

// Backend service with IAP and logging enabled
resource "google_compute_backend_service" "internal_backend" {
  name                  = "${var.prefix}-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http-${local.primary_port}"
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
    oauth2_client_id     = local.iap_client_id
    oauth2_client_secret = local.iap_client_secret
  }

  // Enable request logging for observability
  log_config {
    enable      = true
    sample_rate = 1.0
  }
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
    ports    = [tostring(local.primary_port)]
  }

  source_ranges = [
    "130.211.0.0/22", // Google Cloud health check IPs
    "35.191.0.0/16",  // Google Cloud proxy IPs
  ]

  target_tags = ["${var.prefix}-backend"]
}
