// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "name" {
  description = "The name of the service (must match the name used in gce-regional-container-alb module)."
  type        = string
}

variable "region" {
  description = "The region where the internal load balancer frontend forwarding rule is located."
  type        = string
}

variable "service_account" {
  description = "The email of the service account being authorized to access the internal ALB via IAP."
  type        = string
}
