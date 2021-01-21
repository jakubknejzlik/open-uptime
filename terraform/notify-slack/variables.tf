variable "name" {
  type        = string
  description = "Name of notification function"
}
variable "slack_url" {
  type        = string
  description = "Slack webhook url for sending notifications"
}
variable "slack_channel" {
  type        = string
  description = "Slack channel to send alerts to"
}

variable "event" {
  description = "Event source configuration which triggers the Lambda function. Supported events: cloudwatch-events, dynamodb, sns, sqs"
  type        = map(string)
  default     = {}
}
