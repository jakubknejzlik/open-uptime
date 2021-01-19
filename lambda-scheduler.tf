data "archive_file" "lambda-scheduler" {
  type        = "zip"
  source_file = ".tmp/lambda-scheduler"
  output_path = ".tmp/lambda-scheduler.zip"
}

module "scheduler" {
  source = "./terraform/lambda"

  name     = "openuptime-scheduler"
  filename = ".tmp/lambda-scheduler.zip"
  handler  = "lambda-scheduler"
  schedule = "rate(1 minute)"
  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.monitors.name
    SQS_QUEUE_URL       = aws_sqs_queue.schedules.id
  }

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
    }
  ]
}
EOF
}
