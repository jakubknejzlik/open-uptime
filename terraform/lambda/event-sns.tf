resource "aws_sns_topic_subscription" "subscription" {
  count     = lookup(var.event, "type", "") == "sns" ? 1 : 0
  endpoint  = aws_lambda_function.lambda.arn
  protocol  = "lambda"
  topic_arn = lookup(var.event, "source_arn", null)
}

resource "aws_lambda_permission" "sns" {
  count         = lookup(var.event, "type", "") == "sns" ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "sns.amazonaws.com"
  statement_id  = "AllowSubscriptionToSNS"
  source_arn    = lookup(var.event, "source_arn", null)
}
