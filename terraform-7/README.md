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

The first apply can show an empty ALB hostname until the AWS Load Balancer Controller reconciles the Ingress. Wait a few minutes, then run:

```powershell
terraform refresh
terraform output alb_hostname
```

## Notes

- Runtime secrets in `terraform.tfvars` are stored in Terraform state. Move them to AWS Secrets Manager or External Secrets before production use.
- The node IAM role currently grants DynamoDB access to the application pods. For production, split this into IRSA roles per service.
- `quickslot-kgateway` is a minimal Kubernetes gateway layer using Nginx. If you want Gateway API CRDs and `HTTPRoute` later, this stack can be extended without changing the application deployments.
