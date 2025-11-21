# Authorize Internal ALB Caller Module

This module authorizes a service account to access an Internal Application Load Balancer (ALB) protected by Identity-Aware Proxy (IAP) and returns a map of region to private IP addresses.

## Usage

```hcl
module "authorize_caller" {
  source = "chainguard-dev/common/infra//modules/authorize-internal-alb-caller"

  project_id          = var.project_id
  prefix              = "my-service"  # Must match the prefix used in gce-regional-container-alb
  lb_frontend_region  = "us-central1"
  regions             = ["us-central1", "us-east1"]
  service_account     = google_service_account.caller.email
}

# Access the service in any region using the returned IP map
output "service_urls" {
  value = {
    for region, ip in module.authorize_caller.ip_addresses :
    region => "http://${ip}"
  }
}
```

## Description

This module performs the following actions:
1. Looks up the backend service by name using the provided prefix
2. Grants the specified service account the `roles/iap.httpsResourceAccessor` role on the backend service
3. Looks up the internal load balancer forwarding rule
4. Returns a map of region to IP address (all regions map to the same IP since there's a single frontend with global access)

The IP addresses should only be used by the authorized service account to access the ALB.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.79 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 4.79 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_iap_web_backend_service_iam_member.authorize-calls](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_web_backend_service_iam_member) | resource |
| [google_compute_backend_service.backend](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_backend_service) | data source |
| [google_compute_forwarding_rule.internal_alb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_forwarding_rule) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_lb_frontend_region"></a> [lb\_frontend\_region](#input\_lb\_frontend\_region) | The region where the internal load balancer frontend forwarding rule is located. | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The naming prefix used when creating the ALB resources (must match the prefix used in gce-regional-container-alb module). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID. | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | List of regions where the service is available (used to create the region-to-IP mapping). | `list(string)` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The email of the service account being authorized to access the internal ALB via IAP. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ip_addresses"></a> [ip\_addresses](#output\_ip\_addresses) | Map of region to the private IP address of the internal load balancer. All regions map to the same IP since there's a single frontend with global access. |
<!-- END_TF_DOCS -->
