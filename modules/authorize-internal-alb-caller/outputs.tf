// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

output "ip_addresses" {
  description = "Map of region to the private IP address of the internal load balancer. All regions map to the same IP since there's a single frontend with global access."
  value = {
    for region in var.regions :
    region => data.google_compute_forwarding_rule.internal_alb.ip_address
  }
}
