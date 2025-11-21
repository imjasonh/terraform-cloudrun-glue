// Copyright 2025 Chainguard, Inc.
// SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "Name of the service. Resources will be named 'gce-svc-{name}'."
  type        = string
}

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "regions" {
  description = "A map from region names to a network and subnetwork.  A service will be created in each region configured to egress the specified traffic via the specified subnetwork."
  type = map(object({
    network      = string
    subnet       = string
    proxy_subnet = string
  }))
}

variable "service_account" {
  description = "Service account email for the GCE VMs."
  type        = string
}

// TODO variable "containers", to support sidecars
variable "container" {
  description = "Container specification including image, args, env, and ports."
  type = object({
    image = string
    args  = optional(list(string), [])
    env = optional(list(object({
      name  = string
      value = string
    })), [])
    /* TODO
    regional-env = optional(list(object({
      name  = string
      value = map(string)
    })), [])
    */
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
}

variable "disk_size_gb" {
  description = "Boot disk size in GB for each VM."
  type        = number
}

variable "instance_count" {
  description = "Number of instances per regional MIG."
  type        = number
}

variable "iap" {
  description = "IAP OAuth2 credentials for the backend service. Must be manually created in the Google Cloud Console (APIs & Services > Credentials)."
  type = object({
    oauth2_client_id     = string
    oauth2_client_secret = string
  })
  sensitive = true
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



/* TODO scaling
variable "scaling" {
  description = "The scaling configuration for the service."
  type = object({
    min_instances                    = optional(number, 0)
    max_instances                    = optional(number, 100)
    max_instance_request_concurrency = optional(number)
  })
  default = {}
}*/


/* TODO egress
variable "egress" {
  type        = string
  description = <<EOD
Which type of egress traffic to send through the VPC.

- ALL_TRAFFIC sends all traffic through regional VPC network
- PRIVATE_RANGES_ONLY sends only traffic to private IP addresses through regional VPC network
EOD
  default     = "ALL_TRAFFIC"
}
*/

// TODO: notification_channels
