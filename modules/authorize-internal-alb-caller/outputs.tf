// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

output "ip_address" {
  description = "The private IP address of the internal load balancer."
  value       = data.google_compute_forwarding_rule.internal_alb.ip_address
}
