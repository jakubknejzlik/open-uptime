resource "aws_sns_topic_subscription" "subscription" {
  count     = var.event_source_sns_arn != "" ? 1 : 0
  endpoint  = aws_lambda_function.lambda.arn
  protocol  = "lambda"
  topic_arn = var.event_source_sns_arn
}

resource "aws_lambda_permission" "sns" {
  count         = var.event_source_sns_arn != "" ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "sns.amazonaws.com"
  statement_id  = "AllowSubscriptionToSNS"
  source_arn    = var.event_source_sns_arn
}
