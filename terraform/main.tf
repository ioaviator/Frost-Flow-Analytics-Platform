

resource "google_storage_bucket" "frost_flow_bucket" {
  name          = "frost_flow"
  location      = "africa-south1"
  force_destroy = true

   # satisfy the organization policy rule
  uniform_bucket_level_access = true
}