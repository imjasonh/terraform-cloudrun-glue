// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "prefix" {
  description = "The naming prefix used when creating the ALB resources (must match the prefix used in gce-regional-container-alb module)."
  type        = string
}

variable "lb_frontend_region" {
  description = "The region where the internal load balancer frontend forwarding rule is located."
  type        = string
}

variable "regions" {
  description = "List of regions where the service is available (used to create the region-to-IP mapping)."
  type        = list(string)
}

variable "service_account" {
  description = "The email of the service account being authorized to access the internal ALB via IAP."
  type        = string
}
