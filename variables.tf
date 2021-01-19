variable "slack_url" {
  type        = string
  description = "(optional) slack webhook url for sending notifications"
}
variable "slack_channel" {
  type        = string
  description = "(optional) slack channel to send alerts to"
}
