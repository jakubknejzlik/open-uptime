resource "aws_lambda_event_source_mapping" "sqs" {
  count            = lookup(var.event, "type", "") == "sqs" ? 1 : 0
  event_source_arn = lookup(var.event, "source_arn", null)
  function_name    = aws_lambda_function.lambda.arn
}


data "aws_iam_policy" "lambda_sqs_queue_execution" {
  count = lookup(var.event, "type", "") == "sqs" ? 1 : 0
  arn   = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}
resource "aws_iam_role_policy_attachment" "lambda_sqs_queue_execution" {
  count      = lookup(var.event, "type", "") == "sqs" ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = data.aws_iam_policy.lambda_sqs_queue_execution[0].arn
}

# resource "aws_iam_role_policy" "lambda" {
#   count = var.event_source_sqs_arn != "" ? 1 : 0
#   name  = "${var.name}-sqs"
#   role  = aws_iam_role.lambda.id

#   policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "sqs:ReceiveMessage",
#                 "sqs:DeleteMessage",
#                 "sqs:GetQueueAttributes",
#                 "logs:CreateLogGroup",
#                 "logs:CreateLogStream",
#                 "logs:PutLogEvents"
#             ],
#             "Resource": "*"
#         }
#     ]
# }
#   EOF
# }
