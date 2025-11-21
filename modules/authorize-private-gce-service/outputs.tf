// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

output "addr" {
  description = "The private IP address of the internal load balancer."
  value       = "http://${data.google_compute_forwarding_rule.internal_alb.ip_address}"
}
