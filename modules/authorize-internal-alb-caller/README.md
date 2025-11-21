# Authorize Internal ALB Caller Module

This module authorizes a service account to access an Internal Application Load Balancer (ALB) protected by Identity-Aware Proxy (IAP) and returns the private IP address of the load balancer.

## Usage

```hcl
module "authorize_caller" {
  source = "chainguard-dev/common/infra//modules/authorize-internal-alb-caller"

  project_id           = var.project_id
  region               = module.internal_alb.lb_frontend_region
  backend_service_name = module.internal_alb.backend_service_name
  forwarding_rule_name = module.internal_alb.forwarding_rule_name
  service_account      = google_service_account.caller.email
}

# Use the IP address to connect to the service
output "service_url" {
  value = "http://${module.authorize_caller.ip_address}"
}
```

## Description

This module performs two actions:
1. Grants the specified service account the `roles/iap.httpsResourceAccessor` role on the backend service
2. Returns the private IP address of the internal load balancer after authorization is complete

The IP address should only be used by the authorized service account to access the ALB.

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
| [google_compute_forwarding_rule.internal_alb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_forwarding_rule) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backend_service_name"></a> [backend\_service\_name](#input\_backend\_service\_name) | The name of the backend service to authorize access to. | `string` | n/a | yes |
| <a name="input_forwarding_rule_name"></a> [forwarding\_rule\_name](#input\_forwarding\_rule\_name) | The name of the internal load balancer forwarding rule. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region in which the internal load balancer forwarding rule is located. | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The email of the service account being authorized to access the internal ALB via IAP. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ip_address"></a> [ip\_address](#output\_ip\_address) | The private IP address of the internal load balancer. |
<!-- END_TF_DOCS -->
