# Terraform 2 Modular Layout

This folder is a module-based copy of `terraform-1`.

The original `terraform/` and `terraform-1/` folders were not changed.

## Structure

- `modules/network`: VPC, subnets, route tables, NAT, internet gateway
- `modules/security`: security groups
- `modules/load_balancers`: external/internal ALB, target groups, listeners, listener rules
- `modules/app_tier`: backend EC2 launch template, ASG, DynamoDB IAM role/profile
- `modules/web_tier`: frontend EC2 launch template and ASG
- `modules/bastion`: bastion host

## Existing State

`terraform.tfstate` was copied from `terraform-1` so this folder can manage the same existing resources.
The `moved.tf` file maps old flat resource addresses to the new module addresses.

Before applying, always run:

```powershell
terraform plan
```

The expected first modular plan is:

```text
Plan: 0 to add, 0 to change, 0 to destroy.
```

It may show resources as moved into modules. That is normal.

## Manual SQS Queue

Create the queue manually in the AWS console, then update `terraform.tfvars`:

```hcl
sqs_notification_queue_name = "smart-parking-notifications-queue"
sqs_notification_queue_url  = "https://sqs.us-east-1.amazonaws.com/<account-id>/smart-parking-notifications-queue"
sqs_notification_queue_arn  = "arn:aws:sqs:us-east-1:<account-id>:smart-parking-notifications-queue"
```

`terraform-3` does not create the queue. It only passes the queue details to the app tier and grants the EC2 app role permission to use it.

## AWS Secrets Manager App Config

By default, Terraform creates a Secrets Manager secret named `parking-1` and passes its ARN to the app tier:

```hcl
create_app_config_secret = true
app_config_secret_name   = "parking-1"
```

After Terraform creates the secret, add this JSON secret value in the AWS console:

```json
{
  "JWT_SECRET": "change-this-long-random-value",
  "INTERNAL_API_KEY": "change-this-internal-api-key",
  "SEED_ADMIN_EMAIL": "admin@parking.com",
  "SEED_ADMIN_PASSWORD": "change-this-admin-password",
  "SEED_USER_EMAIL": "user@parking.com",
  "SEED_USER_PASSWORD": "change-this-user-password",
  "RAZORPAY_KEY_ID": "your-razorpay-key-id",
  "RAZORPAY_KEY_SECRET": "your-razorpay-key-secret",
  "RAZORPAY_CURRENCY": "INR"
}
```

Terraform does not store these secret values in state with the default settings. It grants the app EC2 role `secretsmanager:GetSecretValue`, and the app launch template fetches the JSON at boot to build the service env files.

If you already have a secret, keep Terraform from creating one and paste the ARN:

```hcl
create_app_config_secret = false
app_config_secret_arn    = "arn:aws:secretsmanager:us-east-1:<account-id>:secret:parking-1-xxxxxx"
```

Optional: Terraform can create the initial secret value version, but the secret value will be stored in Terraform state:

```hcl
create_app_config_initial_secret_version = true
app_config_initial_secret_json           = "{\"JWT_SECRET\":\"change-this-long-random-value\"}"
```

## SNS Booking User Notifications

Terraform creates two SNS topics for booking lifecycle notifications:

- `smart-parking-booking-confirmed`
- `smart-parking-booking-cancelled`

The topic resources are defined in `modules/sns_notifications/main.tf`.

The app EC2 role gets `sns:Publish` access to both topics, and the app tier passes these environment variables to the booking and notification containers:

```text
BOOKING_CONFIRMED_SNS_TOPIC_ARN
BOOKING_CANCELLED_SNS_TOPIC_ARN
```

Recommended booking-user email flow:

```text
Booking Service -> SNS topic -> Notification SQS queue -> Notification Service -> User email
```

To enable the SNS to SQS bridge, set the real manually created SQS queue values:

```hcl
enable_booking_sns_to_sqs_subscription = true
sqs_notification_queue_name            = "smart-parking-notifications-queue"
sqs_notification_queue_url             = "https://sqs.us-east-1.amazonaws.com/<account-id>/smart-parking-notifications-queue"
sqs_notification_queue_arn             = "arn:aws:sqs:us-east-1:<account-id>:smart-parking-notifications-queue"
```

Terraform will then:

- subscribe the notification SQS queue to both booking SNS topics
- add an SQS queue policy that allows those SNS topics to send messages
- output whether the bridge is active as `booking_sns_to_sqs_subscription_enabled`

Optional static email subscribers can be added with:

```hcl
booking_confirmed_email_subscribers = ["user@example.com"]
booking_cancelled_email_subscribers = ["user@example.com"]
```

Each direct SNS email address must confirm the AWS SNS subscription before it receives messages. Direct topic email subscribers receive every message on that topic, so they are better for testing/admin alerts. For real per-user booking emails, the application message should include the booking user's email address and the notification service should send to that address.

## SNS Auto Scaling Notifications

Terraform creates an SNS topic named `smart-parking-asg-ec2-notifications` and subscribes `nimeshsv814@gmail.com`.

The app and web Auto Scaling Groups send these events to the topic:

- EC2 instance launch
- EC2 instance launch error
- EC2 instance terminate
- EC2 instance terminate error

After `terraform apply`, open the AWS SNS confirmation email sent to `nimeshsv814@gmail.com` and confirm the subscription. Emails will not arrive until the subscription is confirmed.

## Edge Stack: Route53, CloudFront, WAF, Manual ACM

This folder can create:

- Route53 public hosted zone
- AWS WAF Web ACL for CloudFront
- CloudFront distribution using the external ALB as origin
- Optional Route53 alias record for the app domain

Manual ACM/custom-domain mode:

```hcl
enable_edge_stack                       = true
enable_acm                              = false
create_route53_hosted_zone              = true
route53_zone_domain_name                = "quickslot.site"
app_domain_name                         = "quickslot.site"
create_cloudfront_route53_alias_record  = false
```

In this mode, Terraform creates the Route53 hosted zone, CloudFront distribution, and WAF. Terraform does not create ACM and does not create the `quickslot.site` Route53 A/AAAA records. CloudFront is created with its default `*.cloudfront.net` domain.

Manual custom-domain mode:

1. Create/validate the ACM certificate manually in `us-east-1`.
2. Add `quickslot.site` and the ACM certificate manually on the CloudFront distribution.
3. Create the Route53 A/AAAA alias manually from `quickslot.site` to the CloudFront distribution.

Terraform ignores CloudFront `aliases` and `viewer_certificate`, so later applies will not remove the manually attached ACM certificate or alternate domain name.

If you later want Terraform to create the Route53 A/AAAA alias records after the CloudFront alternate domain is attached, set:

```hcl
create_cloudfront_route53_alias_record = true
```

Before enabling it, update `terraform.tfvars`:

```hcl
enable_edge_stack      = true
route53_hosted_zone_id = "Zxxxxxxxxxxxx"
app_domain_name        = "parking.example.com"
```

For `quickslot.site` with Terraform-created Route53 hosted zone:

```hcl
enable_edge_stack          = true
create_route53_hosted_zone = true
route53_hosted_zone_id     = ""
route53_zone_domain_name   = "quickslot.site"
app_domain_name            = "quickslot.site"
```

If `enable_edge_stack = false`, Terraform will not create Route53, ACM, CloudFront, WAF, or CloudFront DNS records.

When Terraform creates the hosted zone, the safest sequence is:

```powershell
terraform apply -target=aws_route53_zone.edge
terraform output route53_name_servers
```

Then update those nameservers at the domain registrar for `quickslot.site`.
After DNS delegation is updated, run:

```powershell
terraform apply
```

This avoids ACM certificate validation waiting on a hosted zone that is not yet authoritative for the domain.

Optional:

```hcl
cloudfront_price_class                = "PriceClass_100"
cloudfront_create_ipv6_record         = true
waf_rate_limit                        = 2000
cloudfront_origin_custom_header_name  = ""
cloudfront_origin_custom_header_value = ""
```

Before applying, run:

```powershell
terraform plan
```

Do not apply if Terraform wants to recreate the VPC, ALBs, subnets, security groups, or autoscaling groups unexpectedly. For this edge change, the expected resources should be Route53 hosted zone, WAF, CloudFront, and Secrets Manager. The app launch template may change because the app tier now receives the created secret ARN.
