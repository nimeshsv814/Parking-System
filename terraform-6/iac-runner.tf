data "archive_file" "iac_runner" {
  type        = "zip"
  source_file = "${path.module}/lambda/iac_runner.py"
  output_path = "${path.module}/lambda/iac_runner.zip"
}

resource "aws_iam_role" "iac_runner" {
  name = "quickslot-iac-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iac_runner_basic_execution" {
  role       = aws_iam_role.iac_runner.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "iac_runner" {
  function_name    = var.agent_iac_lambda_name
  role             = aws_iam_role.iac_runner.arn
  runtime          = "python3.12"
  handler          = "iac_runner.handler"
  filename         = data.archive_file.iac_runner.output_path
  source_code_hash = data.archive_file.iac_runner.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      DEFAULT_REGION = var.aws_region
    }
  }

  tags = {
    Name        = var.agent_iac_lambda_name
    Application = "smart-parking"
    Service     = "devops-copilot"
  }
}
