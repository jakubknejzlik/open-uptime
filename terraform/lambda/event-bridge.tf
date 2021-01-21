locals {

}
resource "aws_cloudwatch_event_target" "lambda" {
  count          = lookup(var.event, "type", "") == "cloudwatch-event" ? 1 : 0
  target_id      = "${var.name}Event"
  rule           = replace(lookup(var.event, "rule_id", ""), "${lookup(var.event, "event_bus_name", "")}/", "")
  event_bus_name = lookup(var.event, "event_bus_name", "")
  arn            = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "lambda" {
  count         = lookup(var.event, "type", "") == "cloudwatch-event" ? 1 : 0
  statement_id  = "AllowNotify${var.name}FromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = lookup(var.event, "rule_arn", null)
}
