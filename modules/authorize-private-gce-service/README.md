# Authorize Internal ALB Caller Module

This module authorizes a service account to access an Internal Application Load Balancer (ALB) protected by Identity-Aware Proxy (IAP) and returns the private IP address.

## Usage

```hcl
module "authorize_caller" {
  source = "chainguard-dev/common/infra//modules/authorize-internal-alb-caller"

  project_id      = var.project_id
  name            = "my-service"  # Must match the name used in regional-gce-service
  region          = "us-central1"
  service_account = google_service_account.caller.email
}

# Use the IP address to connect to the service
output "service_url" {
  value = "http://${module.authorize_caller.addr}"
}
```

## Description

This module performs the following actions:
1. Looks up the backend service by name `gce-svc-{name}`
2. Grants the specified service account the `roles/iap.httpsResourceAccessor` role on the backend service
3. Looks up the internal load balancer forwarding rule in the specified region
4. Returns the private IP address of the load balancer

The IP address should only be used by the authorized service account to access the ALB.

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
| [google_iap_web_region_backend_service_iam_member.authorize-calls](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_web_region_backend_service_iam_member) | resource |
| [google_compute_forwarding_rule.internal_alb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_forwarding_rule) | data source |
| [google_compute_region_backend_service.backend](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_region_backend_service) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | The name of the service (must match the name used in regional-gce-service module). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region where the internal load balancer frontend forwarding rule is located. | `string` | n/a | yes |
| <a name="input_service-account"></a> [service-account](#input\_service-account) | The email of the service account being authorized to access the internal ALB via IAP. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_addr"></a> [addr](#output\_addr) | The private IP address of the internal load balancer. |
<!-- END_TF_DOCS -->
