data "archive_file" "lambda-http" {
  type        = "zip"
  source_file = ".tmp/lambda-http"
  output_path = ".tmp/lambda-http.zip"
}

module "handler-http" {
  source = "./terraform/lambda"

  name     = "openuptime-http"
  filename = ".tmp/lambda-http.zip"
  handler  = "lambda-http"

  event_source_sqs_arn = aws_sqs_queue.schedules.arn

  environment_variables = {
    SNS_ARN = aws_sns_topic.results.arn
  }

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sns:Publish"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_sns_topic.results.arn}"
      ]
    }
  ]
}
EOF
}
