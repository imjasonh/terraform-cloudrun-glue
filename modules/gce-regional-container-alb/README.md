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
   - Authorization via separate `authorize-internal-alb-caller` module

5. **Observability**
   - 100% request sampling for access logs
   - Built-in GCE VM metrics (CPU, memory, disk, network)
   - Container logs via Cloud Logging

## Usage

```hcl
module "internal_alb" {
  source = "chainguard-dev/common/infra//modules/gce-regional-container-alb"

  name                      = "my-service"  # Resources will be named gce-svc-my-service
  project_id                = var.project_id
  regions                   = ["us-central1", "us-east1"]
  network_self_link         = module.vpc.network_self_link
  subnetwork_self_link      = module.vpc.subnets_self_links["us-central1"]
  lb_proxy_subnet_self_link = module.vpc.proxy_subnet_self_link
  lb_frontend_region        = "us-central1"
  service_account_email     = google_service_account.vm_sa.email
  
  # Container specification
  container = {
    image = "gcr.io/my-project/my-image:latest"
    args  = ["--port=8080"]
    env = [
      {
        name  = "ENV_VAR"
        value = "value"
      }
    ]
    ports = [
      {
        name           = "http1"
        container_port = 8080
      }
    ]
  }

  # Optional: IAP Configuration (will be auto-created if not provided)
  iap = {
    oauth2_client_id     = var.iap_client_id
    oauth2_client_secret = var.iap_client_secret
  }
  
  # Required if IAP is not provided
  # iap_support_email = "support@example.com"

  # Required: Resource Configuration
  machine_type   = "e2-medium"
  disk_size_gb   = 20
  instance_count = 2

  # Labels
  squad  = "platform"
  labels = {
    environment = "production"
  }
}

# Authorize a caller to access the internal ALB in a specific region
module "authorize_caller_us_central1" {
  source = "chainguard-dev/common/infra//modules/authorize-internal-alb-caller"

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
- A VPC network with appropriate subnets must exist
- A proxy-only subnet must be configured for the load balancer
- If IAP is not provided, `iap_support_email` is required for auto-creation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.79 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 4.79 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 4.79 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_backend_service.internal_backend](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_firewall.allow_health_check_and_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_forwarding_rule.internal_frontend](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_health_check.http_8080](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.container_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_instance_group_manager.mig](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_compute_target_http_proxy.internal_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_url_map.internal_urlmap](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_iap_brand.project_brand](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_brand) | resource |
| [google_iap_client.oauth_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_client) | resource |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container"></a> [container](#input\_container) | Container specification including image, args, env, and ports. | <pre>object({<br/>    image = string<br/>    args  = optional(list(string), [])<br/>    env = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/>    ports = optional(list(object({<br/>      name           = optional(string, "http1")<br/>      container_port = number<br/>      })), [{<br/>      name           = "http1"<br/>      container_port = 8080<br/>    }])<br/>  })</pre> | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Boot disk size in GB for each VM. | `number` | n/a | yes |
| <a name="input_iap"></a> [iap](#input\_iap) | IAP configuration for the backend service. If not provided, a new IAP brand and OAuth client will be created. | <pre>object({<br/>    oauth2_client_id     = string<br/>    oauth2_client_secret = string<br/>  })</pre> | `null` | no |
| <a name="input_iap_support_email"></a> [iap\_support\_email](#input\_iap\_support\_email) | Support email for IAP brand creation. Required if iap is not provided. | `string` | `""` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of instances per regional MIG. | `number` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Additional labels to apply to resources. | `map(string)` | `{}` | no |
| <a name="input_lb_frontend_region"></a> [lb\_frontend\_region](#input\_lb\_frontend\_region) | Region for the internal load balancer frontend forwarding rule. | `string` | n/a | yes |
| <a name="input_lb_proxy_subnet_self_link"></a> [lb\_proxy\_subnet\_self\_link](#input\_lb\_proxy\_subnet\_self\_link) | Proxy-only subnet self-link for the load balancer frontend. | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | VM machine type for the instances. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the service. Resources will be named 'gce-svc-{name}'. | `string` | n/a | yes |
| <a name="input_network_self_link"></a> [network\_self\_link](#input\_network\_self\_link) | VPC network self-link (e.g., from module.vpc.network\_self\_link). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID. | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | List of regions to deploy MIG backends to. | `list(string)` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Service account email for the GCE VMs. | `string` | n/a | yes |
| <a name="input_squad"></a> [squad](#input\_squad) | Squad label to apply to resources (for team attribution). | `string` | `""` | no |
| <a name="input_subnetwork_self_link"></a> [subnetwork\_self\_link](#input\_subnetwork\_self\_link) | Subnet self-link where VMs are placed (e.g., from module.vpc.subnets\_self\_links). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_service_self_link"></a> [backend\_service\_self\_link](#output\_backend\_service\_self\_link) | The self-link of the backend service, required by a separate ALB Frontend module. |
| <a name="output_instance_group_self_links"></a> [instance\_group\_self\_links](#output\_instance\_group\_self\_links) | Map of region to MIG instance group self-link. |
| <a name="output_named_port"></a> [named\_port](#output\_named\_port) | The named port mapping for the service. |
<!-- END_TF_DOCS -->
