data "archive_file" "lambda-notify-slack" {
  type        = "zip"
  source_file = ".tmp/lambda-notify-slack"
  output_path = ".tmp/lambda-notify-slack.zip"
}

resource "aws_iam_role" "notify-slack" {
  name = "openuptime-lambda-notify-slack"

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


resource "aws_iam_role_policy" "notify-slack" {
  name = "openuptime-notify-slack"
  role = aws_iam_role.notify-slack.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
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

resource "aws_lambda_function" "notify-slack" {
  filename      = ".tmp/lambda-notify-slack.zip"
  function_name = "openuptime-notify-slack"
  role          = aws_iam_role.notify-slack.arn
  handler       = "lambda-notify-slack"
  timeout       = "30"

  source_code_hash = data.archive_file.lambda-notify-slack.output_base64sha256

  runtime = "go1.x"

  environment {
    variables = {
      SLACK_URL=var.slack_url
      SLACK_CHANNEL=var.slack_channel
    }
  }

  tags = {
    app = "openuptime"
  }
}

resource "aws_cloudwatch_event_target" "notify-slack" {
  target_id = "OpenuptimeNotifySlack"
  rule = replace(aws_cloudwatch_event_rule.monitor-alert.id,"openuptime/","")
  event_bus_name = "openuptime"
  arn  = aws_lambda_function.notify-slack.arn
}

resource "aws_lambda_permission" "notify-slack" {
  statement_id  = "AllowNotifySlackExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify-slack.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitor-alert.arn
}