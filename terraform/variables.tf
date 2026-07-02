
variable "api_url" {
  type        = string
  description = "API Base URL used for data extraction"
  default     = "https://www.fema.gov/api/open/v2/PublicAssistanceFundedProjectsDetails"

}

variable "email" {
  type        = string
  description = "Email of the logged in user principal on GCP"
}