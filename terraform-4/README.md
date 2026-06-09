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

## Manual AWS Secrets Manager App Config

Create one secret manually in AWS Secrets Manager, then paste its ARN into `terraform.tfvars`:

```hcl
app_config_secret_arn = "arn:aws:secretsmanager:us-east-1:<account-id>:secret:smart-parking/app-config-xxxxxx"
```

Use this JSON structure for the secret value:

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

Terraform does not store these secret values in state. It grants the app EC2 role `secretsmanager:GetSecretValue`, and the app launch template fetches the JSON at boot to build the service env files.

## Edge Stack: Route53, CloudFront, WAF, Optional ACM

This folder can create:

- Optional ACM certificate in `us-east-1`
- Optional DNS validation records in Route53
- AWS WAF Web ACL for CloudFront
- CloudFront distribution using the external ALB as origin
- Route53 alias record for the app domain

Current no-ACM mode:

```hcl
enable_edge_stack          = true
enable_acm                 = false
create_route53_hosted_zone = true
route53_zone_domain_name   = "quickslot.site"
app_domain_name            = "quickslot.site"
```

In no-ACM mode, Terraform creates the Route53 hosted zone, CloudFront distribution, and WAF. Terraform does not create ACM and does not create the `quickslot.site` Route53 A/AAAA records. CloudFront is created with its default `*.cloudfront.net` domain.

Manual custom-domain mode:

1. Create/validate the ACM certificate manually in `us-east-1`.
2. Add `quickslot.site` and the ACM certificate manually on the CloudFront distribution.
3. Create the Route53 A/AAAA alias manually from `quickslot.site` to the CloudFront distribution.

Terraform ignores CloudFront `aliases` and `viewer_certificate`, so later applies will not remove the manually attached ACM certificate or alternate domain name.

To make `quickslot.site` go through CloudFront, CloudFront needs a matching ACM certificate from `us-east-1`. You can either let Terraform create it by setting `enable_acm = true`, or create it manually in ACM and paste the issued ARN:

```hcl
enable_edge_stack            = true
enable_acm                   = false
existing_acm_certificate_arn = "arn:aws:acm:us-east-1:<account-id>:certificate/<certificate-id>"
app_domain_name              = "quickslot.site"
```

When `existing_acm_certificate_arn` is set, Terraform does not create ACM. It attaches that certificate to CloudFront and points the Route53 A/AAAA records for `quickslot.site` to CloudFront. There is no ALB DNS fallback in Route53 for the custom domain.

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
cloudfront_price_class               = "PriceClass_100"
cloudfront_create_ipv6_record        = true
waf_rate_limit                       = 2000
cloudfront_origin_custom_header_name = ""
cloudfront_origin_custom_header_value = ""
```

Before applying, run:

```powershell
terraform plan
```

Do not apply if Terraform wants to recreate the VPC, ALBs, subnets, security groups, launch templates, or autoscaling groups. For the edge change, the expected resources should be ACM, Route53 validation records, WAF, CloudFront, and Route53 alias records.
