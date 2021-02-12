variable "slack_url" {
  type        = string
  description = "(optional) slack webhook url for sending notifications"
}
variable "slack_channel" {
  type        = string
  description = "(optional) slack channel to send alerts to"
}

variable "openid_issuer" {
  type        = string
  description = "(optional) OpenID Connect issuer URL (see more at https://docs.aws.amazon.com/appsync/latest/devguide/security-authz.html#openid-connect-authorization)"
}
