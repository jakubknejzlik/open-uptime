resource "aws_iam_role" "lambda" {
  name = var.name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda" {
  count = var.hasPolicy ? 1 : 0
  name  = var.name
  role  = aws_iam_role.lambda.id

  policy = var.policy
}

data "aws_iam_policy" "aws_xray_write_only_access" {
  arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}
data "aws_iam_policy" "lambda_basic_execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "aws_xray_write_only_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = data.aws_iam_policy.aws_xray_write_only_access.arn
}
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = data.aws_iam_policy.lambda_basic_execution.arn
}

resource "aws_lambda_function" "lambda" {
  filename      = var.filename
  function_name = var.name
  role          = aws_iam_role.lambda.arn
  handler       = var.handler
  timeout       = "50"

  source_code_hash = filebase64sha256(var.filename)

  runtime = "go1.x"

  #   tracing_config {
  #     mode = "Active"
  #   }

  environment {
    variables = var.environment_variables
  }

  tags = {
    app = "openuptime"
  }
}
