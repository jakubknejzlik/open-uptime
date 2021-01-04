data "archive_file" "lambda-scheduler" {
  type        = "zip"
  source_file = ".tmp/lambda-scheduler"
  output_path = ".tmp/lambda-scheduler.zip"
}

resource "aws_iam_role" "scheduler" {
  name = "openuptime-lambda-scheduler"

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

resource "aws_iam_role_policy" "scheduler" {
  name = "openuptime-scheduler"
  role = aws_iam_role.scheduler.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:Scan"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_dynamodb_table.monitors.arn}"
      ]
    },
    {
      "Action": [
        "sqs:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_sqs_queue.schedules.arn}"
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

resource "aws_lambda_function" "scheduler" {
  filename      = ".tmp/lambda-scheduler.zip"
  function_name = "openuptime-scheduler"
  role          = aws_iam_role.scheduler.arn
  handler       = "lambda-scheduler"
  timeout       = "50"

  source_code_hash = data.archive_file.lambda-scheduler.output_base64sha256

  runtime = "go1.x"

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.monitors.name
      SQS_QUEUE_URL       = data.aws_sqs_queue.schedules.url
    }
  }

  tags = {
    app = "openuptime"
  }
}

resource "aws_cloudwatch_event_rule" "scheduler" {
  #   event_bus_name      = aws_cloudwatch_event_bus.main.name
  name                = "openopentime-scheduler"
  description         = "Fires every minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "scheduler" {
  #   event_bus_name = aws_cloudwatch_event_bus.main.name
  rule      = aws_cloudwatch_event_rule.scheduler.name
  target_id = "scheduler"
  arn       = aws_lambda_function.scheduler.arn
}

resource "aws_lambda_permission" "scheduler" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler.arn
}
