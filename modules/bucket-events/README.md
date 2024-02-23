# `bucket-events`

This module provisions infrastructure to listen to events from a GCS bucket and
publish them to a broker.

```hcl
// Create a network with several regional subnets
module "networking" {
  source = "chainguard-dev/common/infra//modules/networking"

  name       = "my-networking"
  project_id = var.project_id
  regions    = [...]
}

// Create the Broker abstraction.
module "cloudevent-broker" {
  source = "chainguard-dev/common/infra//modules/cloudevent-broker"

  name       = "my-broker"
  project_id = var.project_id
  regions    = module.networking.regional-networks
}

// Get the bucket.
data "google_storage_bucket" "bucket" {
  name = "my-bucket"
}

// Listen to events.
module "bucket-events" {
  source = "chainguard-dev/common/infra//modules/bucket-events"

  name       = "my-broker"
  project_id = var.project_id

  bucket   = data.google_storage_bucket.bucket.name
  location = data.google_storage_bucket.bucket.location
  broker   = module.cloudevent-broker.broker

  notification_channels = []
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cosign"></a> [cosign](#provider\_cosign) | n/a |
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | n/a |
| <a name="provider_ko"></a> [ko](#provider\_ko) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_audit-serviceaccount"></a> [audit-serviceaccount](#module\_audit-serviceaccount) | ../audit-serviceaccount | n/a |
| <a name="module_authorize-delivery"></a> [authorize-delivery](#module\_authorize-delivery) | ../authorize-private-service | n/a |
| <a name="module_this"></a> [this](#module\_this) | ../regional-go-service | n/a |
| <a name="module_trampoline-emits-events"></a> [trampoline-emits-events](#module\_trampoline-emits-events) | ../authorize-private-service | n/a |

## Resources

| Name | Type |
|------|------|
| [cosign_sign.this](https://registry.terraform.io/providers/chainguard-dev/cosign/latest/docs/resources/sign) | resource |
| [google-beta_google_project_service_identity.pubsub](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_pubsub_subscription.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_subscription_iam_binding.allow-pubsub-to-ack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription_iam_binding) | resource |
| [google_pubsub_topic.dead-letter](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic.internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_binding.allow-pubsub-to-send-to-dead-letter](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_binding) | resource |
| [google_pubsub_topic_iam_binding.binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_binding) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.allow-pubsub-to-mint-tokens](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_storage_notification.notification](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_notification) | resource |
| [ko_build.this](https://registry.terraform.io/providers/ko-build/ko/latest/docs/resources/build) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [google_storage_project_service_account.gcs_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket"></a> [bucket](#input\_bucket) | The name of the bucket to watch for events. | `string` | n/a | yes |
| <a name="input_filter"></a> [filter](#input\_filter) | A Knative Trigger-style filter over the cloud event attributes. | `map(string)` | n/a | yes |
| <a name="input_gcs_event_types"></a> [gcs\_event\_types](#input\_gcs\_event\_types) | The types of GCS events to watch for (https://cloud.google.com/storage/docs/pubsub-notifications#payload). | `list(string)` | <pre>[<br>  "OBJECT_FINALIZE",<br>  "OBJECT_METADATA_UPDATE",<br>  "OBJECT_DELETE",<br>  "OBJECT_ARCHIVE"<br>]</pre> | no |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | An object holding the name of the ingress service, which can be used to authorize callers to publish cloud events. | <pre>object({<br>    name = string<br>  })</pre> | n/a | yes |
| <a name="input_max_delivery_attempts"></a> [max\_delivery\_attempts](#input\_max\_delivery\_attempts) | The maximum number of delivery attempts for any event. | `number` | `5` | no |
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | n/a | yes |
| <a name="input_notification_channels"></a> [notification\_channels](#input\_notification\_channels) | List of notification channels to alert. | `list(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | n/a | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | A map from region names to a network and subnetwork.  A pub/sub topic and ingress service (publishing to the respective topic) will be created in each region, with the ingress service configured to egress all traffic via the specified subnetwork. | <pre>map(object({<br>    network = string<br>    subnet  = string<br>  }))</pre> | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->