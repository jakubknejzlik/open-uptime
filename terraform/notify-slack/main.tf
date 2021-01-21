data "archive_file" "lambda-notify-slack" {
  type        = "zip"
  source_file = ".tmp/lambda-notify-slack"
  output_path = ".tmp/lambda-notify-slack.zip"
}

module "notify-slack" {
  source = "../lambda"

  name     = var.name
  filename = ".tmp/lambda-notify-slack.zip"
  handler  = "lambda-notify-slack"

  event = var.event

  environment_variables = {
    SLACK_URL     = var.slack_url
    SLACK_CHANNEL = var.slack_channel
  }
}
