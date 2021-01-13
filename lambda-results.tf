data "archive_file" "lambda-results" {
  type        = "zip"
  source_file = ".tmp/lambda-results"
  output_path = ".tmp/lambda-results.zip"
}

resource "aws_iam_role" "results" {
  name = "openuptime-lambda-results"

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

resource "aws_iam_role_policy" "results" {
  name = "openuptime-results"
  role = aws_iam_role.results.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "timestream:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_cloudformation_stack.timestream.outputs.TableARN}"
      ]
    },
    {
      "Action": [
        "timestream:DescribeEndpoints"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    },
    {
      "Action": [
        "sqs:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_sqs_queue.results.arn}"
      ]
    },
    {
      "Action": [
        "dynamodb:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_dynamodb_table.events.arn}",
        "${aws_dynamodb_table.monitors.arn}"
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

resource "aws_lambda_function" "results" {
  filename      = ".tmp/lambda-results.zip"
  function_name = "openuptime-results"
  role          = aws_iam_role.results.arn
  handler       = "lambda-results"
  timeout       = "30"

  source_code_hash = data.archive_file.lambda-results.output_base64sha256

  runtime = "go1.x"

  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = "openuptime"
      TIMESTREAM_TABLE_NAME    = "monitors"
      DYNAMODB_EVENTS_TABLE_NAME = "OpenuptimeEvents"
      DYNAMODB_MONITORS_TABLE_NAME = "OpenuptimeMonitors"
    }
  }

  tags = {
    app = "openuptime"
  }
}

resource "aws_lambda_event_source_mapping" "results" {
  event_source_arn = aws_sqs_queue.results.arn
  function_name    = aws_lambda_function.results.arn
}
