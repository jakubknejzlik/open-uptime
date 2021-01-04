data "archive_file" "lambda-http" {
  type        = "zip"
  source_file = ".tmp/lambda-http"
  output_path = ".tmp/lambda-http.zip"
}

resource "aws_iam_role" "http" {
  name = "openuptime-lambda-http"

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

resource "aws_iam_role_policy" "http" {
  name = "openuptime-http"
  role = aws_iam_role.http.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "timestream:WriteRecords"
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

resource "aws_lambda_function" "http" {
  filename      = ".tmp/lambda-http.zip"
  function_name = "openuptime-http"
  role          = aws_iam_role.http.arn
  handler       = "lambda-http"
  timeout       = "30"

  source_code_hash = data.archive_file.lambda-http.output_base64sha256

  runtime = "go1.x"

  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = "openuptime"
      TIMESTREAM_TABLE_NAME    = "monitors"
    }
  }

  tags = {
    app = "openuptime"
  }
}

resource "aws_lambda_event_source_mapping" "http" {
  event_source_arn = aws_sqs_queue.schedules.arn
  function_name    = aws_lambda_function.http.arn
}
