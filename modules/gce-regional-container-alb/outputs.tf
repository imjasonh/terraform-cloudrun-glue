// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

output "load_balancer_ip" {
  description = "The private IP address of the internal load balancer for clients to access the service."
  value       = google_compute_forwarding_rule.internal_frontend.ip_address
}

output "backend_service_self_link" {
  description = "The self-link of the backend service, required by a separate ALB Frontend module."
  value       = google_compute_backend_service.internal_backend.self_link
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
    name = "http-8080"
    port = 8080
  }
}
