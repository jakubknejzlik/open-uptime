data "archive_file" "lambda-alert" {
  type        = "zip"
  source_file = ".tmp/lambda-alert"
  output_path = ".tmp/lambda-alert.zip"
}

resource "aws_iam_role" "alert" {
  name = "openuptime-lambda-alert"

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

resource "aws_iam_role_policy" "alert" {
  name = "openuptime-alert"
  role = aws_iam_role.alert.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_dynamodb_table.monitors.stream_arn}"
      ]
    },
    {
      "Action": [
        "events:PutEvents"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_cloudwatch_event_bus.main.arn}"
      ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "alert" {
  filename      = ".tmp/lambda-alert.zip"
  function_name = "openuptime-alert"
  role          = aws_iam_role.alert.arn
  handler       = "lambda-alert"
  timeout       = "30"

  source_code_hash = data.archive_file.lambda-alert.output_base64sha256

  runtime = "go1.x"

  environment {
    variables = {
      EVENTBRIDGE_BUS_NAME="openuptime"
    }
  }

  tags = {
    app = "openuptime"
  }
}

resource "aws_lambda_event_source_mapping" "alert" {
  event_source_arn = aws_dynamodb_table.monitors.stream_arn
  function_name    = aws_lambda_function.alert.arn
  starting_position = "LATEST"
}