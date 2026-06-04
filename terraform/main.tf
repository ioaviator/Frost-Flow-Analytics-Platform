

resource "google_storage_bucket" "frost_flow_bucket" {
  name          = "frost-flow-data"
  location      = "africa-south1"
  force_destroy = true

   # satisfy the organization policy rule
  uniform_bucket_level_access = true
}


resource "google_storage_bucket" "cloud_func_source_code" {
  name     = "cloud-func-source-code-zip"
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


resource "google_storage_bucket_object" "cloud_func_source_code_object" {
  name   = "api-function-${data.archive_file.api_function_source_code.output_md5}.zip"
  bucket = google_storage_bucket.cloud_func_source_code.name
  source = data.archive_file.api_function_source_code.output_path
}

# enable cloud apis
resource "google_project_service" "project_apis" {
  for_each = toset([
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",    # Core Cloud Functions API
    "cloudbuild.googleapis.com",        # Compiles code into a container (Mandatory)
    "run.googleapis.com",               # 2nd Gen functions run on Cloud Run
    "artifactregistry.googleapis.com",  # Stores the built container image
    "eventarc.googleapis.com",          # Handles function routing and triggers
    "cloudscheduler.googleapis.com"     # Cloud scheduler
  ])
  

  service            = each.value
  disable_on_destroy = false
}

# Fetch current project information to pull your numerical project ID
data "google_project" "project" {}

# Service account for the API function
resource "google_service_account" "cloud_function_sa" {
  account_id   = "cloud-function-sa"
  display_name = "Cloud Function SA"
  description  = "Service account for the API Cloud Function"
}

# Grant your user account permissions to view the function execution logs
resource "google_project_iam_member" "user_log_viewer" {
  project = data.google_project.project.project_id
  role    = "roles/logging.viewer"
  member  = "user:aviatorifeanyi@gmail.com"
}


# resource "google_project_iam_member" "cloud_build_permissions" {
#   project = data.google_project.project.project_id
#   role    = "roles/storage.objectViewer"
#   member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
# }

# custom SA permissions
resource "google_project_iam_member" "sa_builder_roles" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/cloudbuild.builds.builder",
    "roles/logging.logWriter",
    "roles/artifactregistry.writer"
  ])
  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"

  depends_on = [ google_service_account.cloud_function_sa ]
}

# Create a 30-second delay to give Google's IAM replication engine time to catch up
# Avoid eventual consistency
resource "time_sleep" "wait_for_iam_replication" {
  depends_on = [
    google_project_iam_member.sa_builder_roles
  ]

  create_duration = "55s"
}


resource "google_cloudfunctions2_function" "cloud_func_resource" {
  name        = "frost-flow-api"
  description = "Frost Flow API data connection"
  location = "africa-south1"

  build_config {
    runtime = "python312"
    entry_point = "apiConnect"
    
    # use the custom service account identity
    service_account = google_service_account.cloud_function_sa.id

    source {
      storage_source {
        bucket = google_storage_bucket.cloud_func_source_code.name
        object = google_storage_bucket_object.cloud_func_source_code_object.name
      }
    }
  }

  service_config {
    service_account_email = google_service_account.cloud_function_sa.email

    environment_variables = {
      API_URL = var.api_url
    }
  }

  depends_on = [
    google_project_service.project_apis,
    time_sleep.wait_for_iam_replication,
    google_project_iam_member.sa_builder_roles,
    google_storage_bucket_object.cloud_func_source_code_object

  ]
}


# Grant public invocation access
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = google_cloudfunctions2_function.cloud_func_resource.project
  location = google_cloudfunctions2_function.cloud_func_resource.location
  
  name     = google_cloudfunctions2_function.cloud_func_resource.service_config[0].service
  role     = "roles/run.invoker"
  member   = "allUsers"

  # Force terraform to wait for the function to fully deploy first
  depends_on = [google_cloudfunctions2_function.cloud_func_resource]
}


resource "google_cloud_scheduler_job" "cloud_func_trigger" {
  name             = "cloud_function_trigger"
  description      = "Trigger a cloud function on a given scheduled interval"
  region      = "europe-west1" 
  schedule         = "*/2 * * * *"
  time_zone        = "Africa/Lagos"
  attempt_deadline = "320s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.cloud_func_resource.service_config[0].uri
  }

}
