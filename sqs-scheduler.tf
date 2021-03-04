resource "aws_sqs_queue" "schedules" {
  name                       = "openuptime-schedules"
  visibility_timeout_seconds = "60"
  receive_wait_time_seconds  = "20"
  # delay_seconds = 90
  # max_message_size          = 2048
  # message_retention_seconds = 86400
  # receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.schedules-dlq.arn
    maxReceiveCount     = 1
  })

  tags = {
    app = "openuptime"
  }
}

resource "aws_sqs_queue" "schedules-dlq" {
  name                      = "openuptime-schedules-dlq"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10

  tags = {
    app = "openuptime"
  }
}
