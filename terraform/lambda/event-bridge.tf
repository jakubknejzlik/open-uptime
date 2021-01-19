resource "aws_cloudwatch_event_target" "lambda" {
  count          = var.cloudwatch_event_target_rule_id != "" ? 1 : 0
  target_id      = "${var.name}Event"
  rule           = replace(var.cloudwatch_event_target_rule_id, "${var.cloudwatch_event_target_bus_name}/", "")
  event_bus_name = var.cloudwatch_event_target_bus_name
  arn            = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "lambda" {
  count         = var.cloudwatch_event_target_rule_id != "" ? 1 : 0
  statement_id  = "AllowNotify${var.name}FromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = var.cloudwatch_event_target_rule_arn
}
