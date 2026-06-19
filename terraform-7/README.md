# QuickSlot EKS Stack

This folder is a standalone EKS deployment for QuickSlot. It does not depend on `terraform-6` state and does not modify any existing Terraform folders.

## What It Creates

- New VPC with public and private subnets
- EKS cluster and managed node group
- DynamoDB tables for auth, parking, booking, payment, and notification services
- AWS Load Balancer Controller
- IAM role for QuickSlot application pods to access DynamoDB through IRSA

The Kubernetes application layer is deployed separately from `../infra/helm/quickslot`.

## Routing

The Helm chart creates the public ALB Ingress and sends all traffic to `quickslot-kgateway`. The gateway routes:

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
```

Get the values needed by Helm:

```powershell
terraform output app_pods_role_arn
terraform output public_subnet_ids
```

Deploy the application through Helm:

```powershell
cd ../infra/helm

helm upgrade --install quickslot ./quickslot `
  --namespace quickslot `
  --create-namespace `
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="<APP_PODS_ROLE_ARN>" `
  --set ingress.subnets="{<PUBLIC_SUBNET_1>,<PUBLIC_SUBNET_2>}"
```

Check the application:

```powershell
kubectl get pods -n quickslot
kubectl get ingress -n quickslot
```

When the Ingress `ADDRESS` appears, open `http://<ADDRESS>`.

## Notes

- Runtime secrets are now provided through Helm values and stored in Kubernetes Secret objects. Move them to AWS Secrets Manager or External Secrets before production use.
- The app pod IAM role grants DynamoDB access to the application pods. For production, split this into IRSA roles per service.
- `quickslot-kgateway` is a minimal Kubernetes gateway layer using Nginx. If you want Gateway API CRDs and `HTTPRoute` later, this stack can be extended without changing the application deployments.
