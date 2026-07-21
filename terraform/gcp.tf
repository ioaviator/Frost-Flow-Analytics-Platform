# enable cloud apis
resource "google_project_service" "project_apis" {
  for_each = toset([
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",   # Core Cloud Functions API
    "cloudbuild.googleapis.com",       # Compiles code into a container (Mandatory)
    "run.googleapis.com",              # 2nd Gen functions run on Cloud Run
    "artifactregistry.googleapis.com", # Stores the built container image
    "eventarc.googleapis.com",         # Handles function routing and triggers
    "cloudscheduler.googleapis.com"    # Cloud scheduler
  ])

  service            = each.value
  disable_on_destroy = false
}

# Google storage account
resource "google_storage_bucket" "fema_disaster_bucket" {
  name          = "fema-disaster-data"
  location      = "africa-south1"
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 32 # days
    }
    action {
      type = "Delete"
    }
  }
}

# cloud bucket for function code
resource "google_storage_bucket" "cloud_func_source_code" {
  name          = "cloud-func-source-code-zip"
  location      = "africa-south1"
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# cloud function source code
resource "google_storage_bucket_object" "cloud_func_source_code_object" {
  name   = "api-function-${data.archive_file.api_function_source_code.output_md5}.zip"
  bucket = google_storage_bucket.cloud_func_source_code.name
  source = data.archive_file.api_function_source_code.output_path
}


# Service account for the API function
resource "google_service_account" "cloud_function_sa" {
  account_id   = "fema-disaster-sa"
  display_name = "Cloud Function SA"
  description  = "Service account for the API Cloud Function"
}

# Grant your user account permissions to view the function execution logs
resource "google_project_iam_member" "user_log_viewer" {
  project = data.google_project.project.project_id
  role    = "roles/logging.viewer"
  member  = "user:${var.email}"
}

# Grant the Cloud Build Service Account the necessary permissions
resource "google_project_iam_member" "cloud_build_sa_roles" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/logging.logWriter",
    "roles/artifactregistry.writer"
  ])

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

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

  depends_on = [google_service_account.cloud_function_sa]
}


# Create a 60-second delay to give Google's IAM replication engine time to catch up
# Avoid eventual consistency
resource "time_sleep" "wait_for_iam_replication" {
  depends_on = [
    google_service_account.cloud_function_sa,
    google_project_iam_member.sa_builder_roles,
    google_project_iam_member.user_log_viewer,
    google_project_iam_member.sa_builder_roles
  ]

  create_duration = "75s"
}


resource "google_cloudfunctions2_function" "cloud_func_resource" {
  name        = "fema_disaster_api"
  description = "Fema API data connection"
  location    = "africa-south1"

  build_config {
    runtime     = "python312"
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
    google_service_account.cloud_function_sa,
    google_project_iam_member.cloud_build_sa_roles,
    google_storage_bucket_object.cloud_func_source_code_object
  ]
}


# Grant public invocation access
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = google_cloudfunctions2_function.cloud_func_resource.project
  location = google_cloudfunctions2_function.cloud_func_resource.location

  name   = google_cloudfunctions2_function.cloud_func_resource.service_config[0].service
  role   = "roles/run.invoker"
  member = "allUsers"

  # Force terraform to wait for the function to fully deploy first
  depends_on = [google_cloudfunctions2_function.cloud_func_resource]
}


resource "google_cloud_scheduler_job" "cloud_func_trigger" {
  name             = "cloud_function_trigger"
  description      = "Trigger a cloud function on a given scheduled interval"
  region           = "europe-west1"
  schedule         = "0 */2 * * *"
  time_zone        = "Africa/Lagos"
  attempt_deadline = "120s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.cloud_func_resource.service_config[0].uri
  }
}


# pub sub topic/subscription creation, storage account notification

resource "google_pubsub_topic" "fema_disaster_topic" {
  name = "fema-disaster-topic"
}

resource "google_pubsub_subscription" "fema_disaster_sub" {
  name  = "fema-disaster_subscription"
  topic = google_pubsub_topic.fema_disaster_topic.id

  ack_deadline_seconds = 20
}

resource "google_pubsub_topic_iam_binding" "pubsub_iam_binding" {
  topic   = google_pubsub_topic.fema_disaster_topic.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.fema_disaster_bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.fema_disaster_topic.id
  event_types    = ["OBJECT_FINALIZE"]
  custom_attributes = {
    project = "fema_disaster"
  }
  depends_on = [google_pubsub_topic_iam_binding.pubsub_iam_binding]
}
