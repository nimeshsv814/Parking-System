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
