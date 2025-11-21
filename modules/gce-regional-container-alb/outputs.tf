// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

output "backend_service_name" {
  description = "The name of the backend service for IAP authorization."
  value       = google_compute_backend_service.internal_backend.name
}

output "backend_service_self_link" {
  description = "The self-link of the backend service, required by a separate ALB Frontend module."
  value       = google_compute_backend_service.internal_backend.self_link
}

output "forwarding_rule_name" {
  description = "The name of the internal load balancer forwarding rule."
  value       = google_compute_forwarding_rule.internal_frontend.name
}

output "lb_frontend_region" {
  description = "The region of the internal load balancer forwarding rule."
  value       = google_compute_forwarding_rule.internal_frontend.region
}

output "instance_group_self_links" {
  description = "Map of region to MIG instance group self-link."
  value = {
    for region, mig in google_compute_region_instance_group_manager.mig :
    region => mig.instance_group
  }
}

output "named_port" {
  description = "The named port mapping for the service."
  value = {
    name = "http-${local.primary_port}"
    port = local.primary_port
  }
}
