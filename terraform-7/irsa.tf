data "aws_iam_policy_document" "app_pods_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:quickslot-app"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_pods" {
  name               = "${var.cluster_name}-app-pods-role"
  assume_role_policy = data.aws_iam_policy_document.app_pods_assume_role.json
}

resource "aws_iam_role_policy" "app_pods_dynamodb" {
  name = "${var.cluster_name}-app-pods-dynamodb"
  role = aws_iam_role.app_pods.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = concat(local.dynamodb_table_arns, local.dynamodb_table_index_arns)
      }
    ]
  })
}

resource "kubernetes_service_account" "app" {
  metadata {
    name      = "quickslot-app"
    namespace = kubernetes_namespace.quickslot.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.app_pods.arn
    }
  }

  automount_service_account_token = true
}
