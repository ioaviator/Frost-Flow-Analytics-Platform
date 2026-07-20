variable "project_id" {
  type        = string
  description = "google cloud project id"
}

variable "api_url" {
  type        = string
  description = "API Base URL used for data extraction"
  default     = "https://www.fema.gov/api/open/v2/PublicAssistanceFundedProjectsDetails"

}

variable "email" {
  type        = string
  description = "Email of the logged in user principal on GCP"
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
