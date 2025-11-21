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

variable "container" {
  description = "Container specification including image, args, env, and ports."
  type = object({
    image = string
    args  = optional(list(string), [])
    env = optional(list(object({
      name  = string
      value = string
    })), [])
    ports = optional(list(object({
      name           = optional(string, "http1")
      container_port = number
      })), [{
      name           = "http1"
      container_port = 8080
    }])
  })
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

variable "iap" {
  description = "IAP configuration for the backend service. If not provided, a new IAP brand and OAuth client will be created."
  type = object({
    oauth2_client_id     = string
    oauth2_client_secret = string
  })
  default   = null
  sensitive = true
}

variable "iap_support_email" {
  description = "Support email for IAP brand creation. Required if iap is not provided."
  type        = string
  default     = ""

  validation {
    condition     = var.iap != null || var.iap_support_email != ""
    error_message = "iap_support_email must be provided when iap is not specified (for IAP brand auto-creation)."
  }
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
