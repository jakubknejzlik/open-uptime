resource "aws_cloudwatch_event_rule" "scheduler" {
  count               = var.schedule != "" ? 1 : 0
  name                = "${var.name}-scheduler"
  description         = "Fires every minute"
  schedule_expression = var.schedule
}

resource "aws_cloudwatch_event_target" "scheduler" {
  count     = var.schedule != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.scheduler[0].name
  target_id = "${var.name}Scheduler"
  arn       = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "scheduler" {
  count         = var.schedule != "" ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler[0].arn
}
