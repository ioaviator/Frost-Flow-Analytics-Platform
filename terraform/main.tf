

resource "google_storage_bucket" "frost_flow_bucket" {
  name          = "frost_flow_data"
  location      = "africa-south1"
  force_destroy = true

   # satisfy the organization policy rule
  uniform_bucket_level_access = true
}



resource "google_storage_bucket" "cloud_func_source_code" {
  name     = "cloud_func_source_code_zip"
  location = "africa-south1"
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# Package the function source code into a zip
data "archive_file" "api_function_source_code" {
  type        = "zip"
  output_path = "${path.module}/.build/api-function-source-code.zip"

   # Point to the api directory and pull all files
  dynamic "source" {
    for_each = fileset("${path.module}/../api", "**")
    content {
      content  = file("${path.module}/../api/${source.value}")
      filename = source.value
    }
  }

  # Point to the requirements.txt file
  source {
    content  = file("${path.module}/../requirements.txt")
    filename = "requirements.txt"
  }
}


resource "google_storage_bucket_object" "cloud_func_source_code_object" {
  name   = "api-function-${data.archive_file.api_function_source_code.output_md5}.zip"
  bucket = google_storage_bucket.cloud_func_source_code.name
  source = data.archive_file.api_function_source_code.output_path
}


# resource "google_cloud_scheduler_job" "cloud_func_trigger" {
#   name             = "cloud_function_trigger"
#   description      = "Trigger a cloud function on a given scheduled interval"
#   schedule         = "*/20 * * * *"
#   time_zone        = "Africa/Lagos"
#   attempt_deadline = "320s"

#   retry_config {
#     retry_count = 1
#   }

#   http_target {
#     http_method = "POST"
#     uri         = "https://example.com/"
#   }

# }