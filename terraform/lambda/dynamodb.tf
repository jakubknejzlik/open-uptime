resource "aws_lambda_event_source_mapping" "dynamodb" {
  count             = var.event_source_dynamodb_stream_arn != "" ? 1 : 0
  event_source_arn  = var.event_source_dynamodb_stream_arn
  function_name     = aws_lambda_function.lambda.arn
  starting_position = var.event_source_dynamodb_starting_position
}

data "aws_iam_policy" "lambda_dynamodb_stream_execution" {
  count = var.event_source_dynamodb_stream_arn != "" ? 1 : 0
  arn   = "arn:aws:iam::aws:policy/AWSLambdaInvocation-DynamoDB"
}
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_stream_execution" {
  count      = var.event_source_dynamodb_stream_arn != "" ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = data.aws_iam_policy.lambda_dynamodb_stream_execution[0].arn
}

# resource "aws_iam_role_policy" "lambda" {
#   count = var.policy != "" ? 1 : 0
#   name  = "${var.name}-dynamodb"
#   role  = aws_iam_role.lambda.id

#   policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "lambda:InvokeFunction"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "dynamodb:DescribeStream",
#                 "dynamodb:GetRecords",
#                 "dynamodb:GetShardIterator",
#                 "dynamodb:ListStreams"
#             ],
#             "Resource": "*"
#         }
#     ]
# }
#   EOF
# }
