resource "aws_cloudwatch_event_bus" "main" {
  name = "openuptime"

  tags = {
    app = "openuptime"
  }
}

resource "aws_sqs_queue" "test" {
  name                       = "openuptime-test"
  visibility_timeout_seconds = "60"
  receive_wait_time_seconds  = "20"

  tags = {
    app = "openuptime"
  }
}

resource "aws_cloudwatch_event_rule" "monitor-alert" {
  name        = "capture-monitor-alerts"
  description = "Capture monitor alert events"
  event_bus_name = "openuptime"

  event_pattern = <<EOF
{
  "detail-type": [
    "OpenUptime Monitor Alert"
  ]
}
EOF
}