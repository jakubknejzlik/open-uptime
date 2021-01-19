resource "aws_sqs_queue" "results" {
  name                       = "openuptime-results"
  visibility_timeout_seconds = "60"
  receive_wait_time_seconds  = "20"
  # delay_seconds = 90
  # max_message_size          = 2048
  # message_retention_seconds = 86400
  # receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.results-dlq.arn
    maxReceiveCount     = 1
  })

  tags = {
    app = "openuptime"
  }
}

resource "aws_sqs_queue" "results-dlq" {
  name                      = "openuptime-results-dlq"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_sns_topic_subscription" "results-sns-to-sqs" {
  topic_arn            = aws_sns_topic.results.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.results.arn
  raw_message_delivery = true
}

resource "aws_sqs_queue_policy" "results" {
  queue_url = aws_sqs_queue.results.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "sqs:SendMessage",
    "Resource": "${aws_sqs_queue.results.arn}",
    "Condition": {
      "ArnEquals": {
        "aws:SourceArn": "${aws_sns_topic.results.arn}"
      }
    }
  }]
}
POLICY
}

