resource "aws_cloudwatch_event_bus" "main" {
  name = "openuptime"

  tags = {
    app = "openuptime"
  }
}

