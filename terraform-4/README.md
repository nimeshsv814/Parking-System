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

In no-ACM mode, `quickslot.site` points to the external ALB. CloudFront and WAF are still created, but CloudFront is accessed using its default `*.cloudfront.net` domain.

To make `quickslot.site` go through CloudFront, ACM must be enabled later because CloudFront requires a matching certificate for custom domains.

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
