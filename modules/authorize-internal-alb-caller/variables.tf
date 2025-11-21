// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region in which the internal load balancer forwarding rule is located."
  type        = string
}

variable "backend_service_name" {
  description = "The name of the backend service to authorize access to."
  type        = string
}

variable "forwarding_rule_name" {
  description = "The name of the internal load balancer forwarding rule."
  type        = string
}

variable "service_account" {
  description = "The email of the service account being authorized to access the internal ALB via IAP."
  type        = string
}
