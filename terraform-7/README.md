# QuickSlot EKS Stack

This folder is a standalone EKS deployment for QuickSlot. It does not depend on `terraform-6` state and does not modify any existing Terraform folders.

## What It Creates

- New VPC with public and private subnets
- EKS cluster and managed node group
- DynamoDB tables for auth, parking, booking, payment, and notification services
- AWS Load Balancer Controller
- Public Application Load Balancer through Kubernetes Ingress
- In-cluster `quickslot-kgateway` Nginx gateway for path routing and rewrites
- Deployments and ClusterIP services for frontend and backend services
- S3 bucket encrypted with KMS for booking/payment invoice PDFs
- Secrets Manager runtime config secret
- SNS booking topics and SQS notification queue with DLQ
- CloudWatch log groups, alarms, and dashboard for application and AWS service health
- EventBridge invoice-created, EKS cluster state, and EKS node group state notifications to an observability SNS topic
- VPC endpoints for private node access to S3, DynamoDB, SSM, Secrets Manager, SQS, SNS, KMS, and CloudWatch Logs
- Optional CloudFront, WAF, and Route53 edge layer

## Routing

The public ALB sends all traffic to `quickslot-kgateway`. The gateway routes:

- `/auth/*` and `/api/auth/*` to `auth-service`
- `/parking/*` and `/api/parking/*` to `parking-service`
- `/booking/*`, `/api/booking/*`, `/ai/*`, and `/api/ai/*` to `booking-service`
- `/payment/*` and `/api/payment/*` to `payment-service`
- `/notification/*` and `/api/notification/*` to `notification-service`
- `/` to `frontend`

The gateway keeps the important path rewrites from the EC2/Nginx stack, such as `/api/payment/create-order` to `/payments/razorpay/order`.

## Deploy

```powershell
cd Parking-System/terraform-7
copy terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Configure kubectl:

```powershell
aws eks update-kubeconfig --region us-east-1 --name quickslot-eks
kubectl get pods -n quickslot
kubectl get ingress -n quickslot
```

Get the ALB:

```powershell
terraform output alb_hostname
```

Get observability resources:

```powershell
terraform output cloudwatch_dashboard_name
terraform output cloudwatch_log_groups
terraform output cloudwatch_alarm_names
terraform output eventbridge_rule_names
terraform output observability_sns_topic_arn
```

The first apply can show an empty ALB hostname until the AWS Load Balancer Controller reconciles the Ingress. Wait a few minutes, then run:

```powershell
terraform refresh
terraform output alb_hostname
```

## Optional Edge

CloudFront and WAF are disabled by default so the working EKS deployment is not blocked by DNS or certificate setup. After the ALB hostname exists, set:

```hcl
enable_edge_stack             = true
cloudfront_origin_domain_name = "<alb-hostname>"
```

For a custom domain, also set:

```hcl
app_domain_name                         = "app.example.com"
cloudfront_certificate_arn              = "arn:aws:acm:us-east-1:<account-id>:certificate/<id>"
route53_hosted_zone_id                  = "Zxxxxxxxxxxxx"
create_cloudfront_route53_alias_record  = true
```

## Notes

- Terraform creates a Secrets Manager secret named by `app_config_secret_name`. If `manage_app_config_secret_value = true`, the secret values are stored in Terraform state.
- The app pod IRSA role grants DynamoDB, S3/KMS invoice, Secrets Manager, SNS, SQS, and CloudWatch Logs access to the application pods. For production, split this into IRSA roles per service.
- CloudWatch log groups are created for each service. The app pods receive `CLOUDWATCH_LOG_GROUP` env vars; application code or a log agent can use those groups for centralized logs.
- `quickslot-kgateway` is a minimal Kubernetes gateway layer using Nginx. If you want Gateway API CRDs and `HTTPRoute` later, this stack can be extended without changing the application deployments.
