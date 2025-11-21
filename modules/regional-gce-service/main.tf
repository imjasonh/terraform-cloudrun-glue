// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

// :old-man-yells-at-google:
// https://docs.cloud.google.com/compute/docs/containers/migrate-containers#compare-container-options

terraform {
  required_providers {
    google      = { source = "hashicorp/google" }
    google-beta = { source = "hashicorp/google-beta" }
  }
}

locals {
  service_name = "gce-svc-${var.name}"

  default_labels = {
    basename(abspath(path.module)) = var.name
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
        name    = local.service_name
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

// Look up subnet self_link from name and region
data "google_compute_subnetwork" "regional" {
  for_each = var.regions

  project = var.project_id
  name    = each.value.subnet
  region  = each.key
}

// Look up proxy subnet self_link from name and region
data "google_compute_subnetwork" "proxy" {
  for_each = var.regions

  project = var.project_id
  name    = each.value.proxy_subnet
  region  = each.key
}

// Instance template for Container-Optimized OS VMs (one per region)
resource "google_compute_instance_template" "container_vm" {
  for_each = var.regions

  name_prefix  = "${local.service_name}-${each.key}-"
  project      = var.project_id
  machine_type = var.machine_type
  tags         = ["${local.service_name}-backend"]

  labels = local.merged_labels

  disk {
    source_image = "cos-cloud/cos-stable"
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size_gb
  }

  network_interface {
    network    = each.value.network
    subnetwork = data.google_compute_subnetwork.regional[each.key].self_link
  }

  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }

  metadata = {
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
    gce-container-declaration = local.container_manifest // NB: deprecated :(
  }

  lifecycle {
    create_before_destroy = true
  }
}

// Regional instance group managers (MIGs) for each region
resource "google_compute_region_instance_group_manager" "mig" {
  for_each = var.regions

  name    = "${local.service_name}-${each.key}"
  project = var.project_id
  region  = each.key

  base_instance_name = "${local.service_name}-${each.key}"
  target_size        = var.instance_count

  version {
    instance_template = google_compute_instance_template.container_vm[each.key].id
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
  name    = "${local.service_name}-http-${local.primary_port}"
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

// Regional backend services with logging enabled (one per region)
resource "google_compute_region_backend_service" "internal_backend" {
  for_each = var.regions

  name                  = "${local.service_name}-${each.key}"
  project               = var.project_id
  region                = each.key
  protocol              = "HTTP"
  port_name             = "http-${local.primary_port}"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.http_8080.id]

  // Add backend for this region's MIG
  backend {
    group           = google_compute_region_instance_group_manager.mig[each.key].instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  // Enable request logging for observability
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

// Regional URL maps that route all traffic to the backend service
resource "google_compute_region_url_map" "internal_urlmap" {
  for_each = var.regions

  name            = "${local.service_name}-${each.key}-urlmap"
  project         = var.project_id
  region          = each.key
  default_service = google_compute_region_backend_service.internal_backend[each.key].id
}

// Regional HTTP proxies for the URL maps
resource "google_compute_region_target_http_proxy" "internal_proxy" {
  for_each = var.regions

  name    = "${local.service_name}-${each.key}-proxy"
  project = var.project_id
  region  = each.key
  url_map = google_compute_region_url_map.internal_urlmap[each.key].id
}

// Internal forwarding rules (Load Balancer frontend) - one per region
resource "google_compute_forwarding_rule" "internal_frontend" {
  for_each = var.regions

  name                  = "${local.service_name}-${each.key}"
  project               = var.project_id
  region                = each.key
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.internal_proxy[each.key].id
  network               = each.value.network
  subnetwork            = data.google_compute_subnetwork.regional[each.key].self_link
  allow_global_access   = true

  labels = local.merged_labels
}

// Firewall rules to allow health check and proxy traffic (one per region)
resource "google_compute_firewall" "allow_health_check_and_proxy" {
  for_each = var.regions

  name    = "${local.service_name}-allow-health-proxy-${each.key}"
  project = var.project_id
  network = each.value.network

  allow {
    protocol = "tcp"
    ports    = [tostring(local.primary_port)]
  }

  source_ranges = [
    "130.211.0.0/22", // Google Cloud health check IPs
    "35.191.0.0/16",  // Google Cloud proxy IPs
  ]

  target_tags = ["${local.service_name}-backend"]
}


