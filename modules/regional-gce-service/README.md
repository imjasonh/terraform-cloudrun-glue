# GCE Cross-Region Internal Application Load Balancer Container Module

This module creates a fully-secured and observable regional backend for a Cross-Region Internal Application Load Balancer (ALB) running containerized workloads on Google Compute Engine (GCE) Managed Instance Groups (MIGs).

## Features

- **Containerized Compute**: Runs container images on GCE VMs using Container-Optimized OS (COS)
- **Multi-Region Deployment**: Deploys MIGs across multiple regions for high availability
- **Security**: Enforces access control using Identity-Aware Proxy (IAP)
- **Observability**: Enables request logging on the ALB and system/container metrics on GCE VMs
- **Integration**: Designed to work with Chainguard's networking modules

## Architecture

The module provisions:

1. **Backend Compute**
   - Instance template with Container-Optimized OS
   - Regional Managed Instance Groups (MIGs) in each specified region
   - Container serving on port 8080

2. **Load Balancer Backend**
   - HTTP health check on port 8080
   - Backend service with IAP and access logging enabled
   - Aggregates all regional MIGs

3. **Load Balancer Frontend**
   - URL map routing all traffic to the backend service
   - HTTP proxy
   - Internal forwarding rule with global access enabled

4. **Security**
   - IAP-protected backend service (with auto-creation option)
   - Firewall rules for health checks and proxy traffic
   - Authorization via separate `authorize-private-gce-service` module

5. **Observability**
   - 100% request sampling for access logs
   - Built-in GCE VM metrics (CPU, memory, disk, network)
   - Container logs via Cloud Logging

## Usage

```hcl
module "internal_alb" {
  source = "chainguard-dev/common/infra//modules/regional-gce-service"

  name            = "my-service"  # Resources will be named gce-svc-my-service
  project_id      = var.project_id
  service_account = google_service_account.vm_sa.email

  regions = {
    "us-central1" = {
      network = module.vpc.network_self_link
      subnet  = module.vpc.subnets_self_links["us-central1"]
    }
    "us-east1" = {
      network = module.vpc.network_self_link
      subnet  = module.vpc.subnets_self_links["us-east1"]
    }
  }
  
  # Container specification
  container = {
    image = "gcr.io/my-project/my-image:latest"
    args  = ["--foo=bar"]
    env = [
      {
        name  = "FOO"
        value = "bar"
      }
    ]
  }

  # Required: IAP OAuth2 credentials (must be manually created in GCP Console; can be reused for multiple services)
  iap = {
    oauth2_client_id     = var.iap_client_id
    oauth2_client_secret = var.iap_client_secret
  }

  # Resource Configuration
  machine_type   = "e2-medium"
  disk_size_gb   = 20
  instance_count = 2

  squad  = "platform"
  labels = {
    environment = "production"
  }
}

# Authorize a caller to access the internal ALB in a specific region
module "authorize_caller_us_central1" {
  source = "chainguard-dev/common/infra//modules/authorize-private-gce-service"

  project_id      = var.project_id
  name            = "my-service"  # Must match the name used above
  region          = "us-central1"
  service_account = google_service_account.caller.email
}

# Use the IP address to connect to the service
output "service_url" {
  value = "http://${module.authorize_caller_us_central1.ip_address}"
}
```

## Requirements

- The container must listen on port 8080 (configurable via `container.ports`)
- A VPC network with appropriate subnets must exist for each region
- **Identity-Aware Proxy (IAP) must be manually enabled** in the Google Cloud Console:
  1. Go to **Security > Identity-Aware Proxy**
  2. Select each regional backend service created by this module (named `gce-svc-{name}-{region}`)
  3. Click **Turn on IAP**
  4. Choose **Google-Managed OAuth** (recommended)
  5. Use the `authorize-private-gce-service` module to grant IAP access to service accounts via Terraform

  Note: Google-managed OAuth cannot be configured via Terraform - it must be enabled through the Console UI

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.allow_health_check_and_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_forwarding_rule.internal_frontend](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_health_check.http_8080](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.container_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_backend_service.internal_backend](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_instance_group_manager.mig](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_compute_region_target_http_proxy.internal_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_http_proxy) | resource |
| [google_compute_region_url_map.internal_urlmap](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_url_map) | resource |
| [google_compute_subnetwork.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.regional](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container"></a> [container](#input\_container) | Container specification including image, args, env, and ports. | <pre>object({<br/>    image = string<br/>    args  = optional(list(string), [])<br/>    env = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/>    /* TODO<br/>    regional-env = optional(list(object({<br/>      name  = string<br/>      value = map(string)<br/>    })), [])<br/>    */<br/>    ports = optional(list(object({<br/>      name           = optional(string, "http1")<br/>      container_port = number<br/>      })), [{<br/>      name           = "http1"<br/>      container_port = 8080<br/>    }])<br/>  })</pre> | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Boot disk size in GB for each VM. | `number` | n/a | yes |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of instances per regional MIG. | `number` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Additional labels to apply to resources. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | VM machine type for the instances. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the service. Resources will be named 'gce-svc-{name}'. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID. | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | A map from region names to a network and subnetwork.  A service will be created in each region configured to egress the specified traffic via the specified subnetwork. | <pre>map(object({<br/>    network      = string<br/>    subnet       = string<br/>    proxy_subnet = string<br/>  }))</pre> | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Service account email for the GCE VMs. | `string` | n/a | yes |
| <a name="input_squad"></a> [squad](#input\_squad) | Squad label to apply to resources (for team attribution). | `string` | `""` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
