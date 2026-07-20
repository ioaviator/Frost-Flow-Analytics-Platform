
# Fetch current project information to pull your numerical project ID
data "google_project" "project" {}

# Enable notifications by giving the correct IAM permission to the storage service account.
data "google_storage_project_service_account" "gcs_account" {
}

data "google_storage_bucket" "fema_disaster_bkt" {
  name = google_storage_bucket.fema_disaster_bucket.name
}

# Package the function source code into a zip
data "archive_file" "api_function_source_code" {
  type        = "zip"
  output_path = "${path.module}/.build/api-function-source-code.zip"

  # Point to the api directory and pull all files
  dynamic "source" {
    for_each = fileset("${path.module}/../api", "**/*.py")
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

