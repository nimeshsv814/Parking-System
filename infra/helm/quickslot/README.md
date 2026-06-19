# QuickSlot Helm Chart

This chart contains the Kubernetes application resources for the QuickSlot EKS deployment.

It includes:

- `templates/common`: Namespace, Runtime Secret, IRSA-ready ServiceAccount, ALB Ingress
- `templates/frontend`: frontend Deployment and Service
- `templates/auth-service`: auth Deployment and Service
- `templates/parking-service`: parking Deployment and Service
- `templates/booking-service`: booking Deployment and Service
- `templates/payment-service`: payment Deployment and Service
- `templates/scheduler-service`: scheduler Deployment and Service
- `templates/notification-service`: notification Deployment and Service
- `templates/kgateway`: Nginx gateway ConfigMap, Deployment, and Service

There are no helper templates in this chart; each resource file is explicit.

## Render Locally

```bash
helm template quickslot ./infra/helm/quickslot
```

## Install

After applying `terraform-7`, get the app pod role ARN and public subnet IDs:

```powershell
cd ../../../terraform-7
terraform output app_pods_role_arn
terraform output public_subnet_ids
```

Update `values.yaml` or copy `values.example.yaml` and fill real runtime secret values. Then install:

```powershell
cd ../infra/helm
helm upgrade --install quickslot ./quickslot `
  --namespace quickslot `
  --create-namespace `
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="<APP_PODS_ROLE_ARN>" `
  --set ingress.subnets="{<PUBLIC_SUBNET_1>,<PUBLIC_SUBNET_2>}"
```

## Important

The Terraform EKS stack still creates infrastructure resources such as EKS, DynamoDB, IAM, the AWS Load Balancer Controller, and IRSA roles. This Helm chart is for the Kubernetes application layer.

For pods to access DynamoDB, set:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/quickslot-eks-app-pods-role
```
