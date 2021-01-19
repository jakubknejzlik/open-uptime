variable "name" {
  type        = string
  description = "Function name"
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Function environment variables"
}

variable "tags" {
  type = map(string)
  default = {
    app = "openuptime"
  }
  description = "Custom tags"
}

variable "filename" {
  type        = string
  description = "Filename of file to upload"
}

variable "handler" {
  type        = string
  description = "Function handler"
}
variable "runtime" {
  type        = string
  default     = "go1.x"
  description = "Function runtime"
}

variable "schedule" {
  type        = string
  default     = ""
  description = "Schedule function using EventBridge"
}

variable "event_source_sqs_arn" {
  type        = string
  default     = ""
  description = "ARN of SQS queue to be used as lambda event source"
}

variable "event_source_dynamodb_stream_arn" {
  type        = string
  default     = ""
  description = "ARN of DynamoDB stream to be used as lambda event source"
}
variable "event_source_dynamodb_starting_position" {
  type        = string
  default     = "LATEST"
  description = "Starting position DynamoDB stream event source"
}

variable "policy" {
  type        = string
  default     = ""
  description = "Custom IAM policy applied to lambda role"
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
