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

  cloudwatch_event_target_bus_name = var.cloudwatch_event_target_bus_name
  cloudwatch_event_target_rule_arn = var.cloudwatch_event_target_rule_arn
  cloudwatch_event_target_rule_id  = var.cloudwatch_event_target_rule_id

  environment_variables = {
    SLACK_URL     = var.slack_url
    SLACK_CHANNEL = var.slack_channel
  }
}
