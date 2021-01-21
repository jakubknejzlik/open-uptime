module "notify-slack" {
  count  = var.slack_url != "" ? 1 : 0
  source = "./terraform/notify-slack"
  name   = "openuptime-notify-slack"

  # cloudwatch_event_target_bus_name = "openuptime"
  # cloudwatch_event_target_rule_arn = aws_cloudwatch_event_rule.monitor-alert.arn
  # cloudwatch_event_target_rule_id  = aws_cloudwatch_event_rule.monitor-alert.id
  event = {
    type           = "cloudwatch-event"
    event_bus_name = "openuptime"
    rule_id        = aws_cloudwatch_event_rule.monitor-alert.id
    rule_arn       = aws_cloudwatch_event_rule.monitor-alert.arn
  }

  slack_url     = var.slack_url
  slack_channel = var.slack_channel

  depends_on = [aws_cloudwatch_event_bus.main]
}
