// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

variable "prefix" {
  description = "Naming prefix for all resources."
  type        = string
}

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "regions" {
  description = "List of regions to deploy MIG backends to."
  type        = list(string)
}

variable "network_self_link" {
  description = "VPC network self-link (e.g., from module.vpc.network_self_link)."
  type        = string
}

variable "subnetwork_self_link" {
  description = "Subnet self-link where VMs are placed (e.g., from module.vpc.subnets_self_links)."
  type        = string
}

variable "lb_proxy_subnet_self_link" {
  description = "Proxy-only subnet self-link for the load balancer frontend."
  type        = string
}

variable "lb_frontend_region" {
  description = "Region for the internal load balancer frontend forwarding rule."
  type        = string
}

variable "service_account_email" {
  description = "Service account email for the GCE VMs."
  type        = string
}

variable "container_image" {
  description = "Docker image URL to run in the container."
  type        = string
}

variable "machine_type" {
  description = "VM machine type for the instances."
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB for each VM."
  type        = number
  default     = 20
}

variable "instance_count" {
  description = "Number of instances per regional MIG."
  type        = number
  default     = 2
}

variable "iap_oauth_client_id" {
  description = "IAP OAuth Client ID for securing the backend service."
  type        = string
}

variable "iap_oauth_client_secret" {
  description = "IAP OAuth Client Secret for securing the backend service."
  type        = string
  sensitive   = true
}

variable "authorized_service_accounts" {
  description = "List of service account emails to grant IAP access (roles/iap.httpsResourceAccessor)."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Additional labels to apply to resources."
  type        = map(string)
  default     = {}
}

variable "squad" {
  description = "Squad label to apply to resources (for team attribution)."
  type        = string
  default     = ""
}
