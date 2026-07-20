variable "project_id" {
  type        = string
  description = "Google cloud project id"
}

variable "storage_int" {
  type        = string
  description = "Snowflake storage integration service account"
}

variable "notification_integration" {
  type        = string
  description = "Snowflake notification connected to gcp pub/sub"
}

variable "org_name" {
  type        = string
  description = "snowflake organization name"
}

variable "account_name" {
  type        = string
  description = "snowflake account name"
}

variable "username" {
  type        = string
  description = "snowflake username"
}

variable "password" {
  type        = string
  description = "snowflake password"
}
