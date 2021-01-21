data "archive_file" "lambda-alert" {
  type        = "zip"
  source_file = ".tmp/lambda-alert"
  output_path = ".tmp/lambda-alert.zip"
}
module "handler-alert" {
  source = "./terraform/lambda"

  name     = "openuptime-alert"
  filename = ".tmp/lambda-alert.zip"
  handler  = "lambda-alert"

  event = {
    type       = "sns"
    source_arn = aws_sns_topic.status-changes.arn
  }


  environment_variables = {
    EVENTBRIDGE_BUS_NAME = "openuptime"
    DYNAMODB_TABLE_NAME  = aws_dynamodb_table.main.id
  }

  hasPolicy = true
  policy    = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_dynamodb_table.main.arn}"
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
    }
  ]
}
EOF
}
