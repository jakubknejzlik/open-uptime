resource "aws_sns_topic" "results" {
  name = "openuptime-results"
}
data "archive_file" "lambda-results" {
  type        = "zip"
  source_file = ".tmp/lambda-results"
  output_path = ".tmp/lambda-results.zip"
}

module "results" {
  source = "./terraform/lambda"

  name     = "openuptime-results"
  filename = ".tmp/lambda-results.zip"
  handler  = "lambda-results"

  event_source_sqs_arn = aws_sqs_queue.results.arn

  environment_variables = {
    TIMESTREAM_DATABASE_NAME     = "openuptime"
    TIMESTREAM_TABLE_NAME        = "monitors"
    DYNAMODB_MONITORS_TABLE_NAME = aws_dynamodb_table.monitors.id
  }

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
        "${aws_dynamodb_table.monitors.arn}"
      ]
    }
  ]
}
EOF
}
