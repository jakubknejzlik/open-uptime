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

variable "cloudwatch_event_target_rule_id" {
  type        = string
  default     = ""
  description = "Rule id of cloudwatch event target"
}
variable "cloudwatch_event_target_rule_arn" {
  type        = string
  default     = ""
  description = "Rule id of cloudwatch event target"
}
variable "cloudwatch_event_target_bus_name" {
  type        = string
  default     = "default"
  description = "CloudWatch event bus name"
}
