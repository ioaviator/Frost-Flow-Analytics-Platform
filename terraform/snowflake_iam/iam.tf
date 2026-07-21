data "google_project" "project" {}

# grant snowflake storage integration access to storage bucket
resource "google_storage_bucket_iam_member" "storage_bucket_member" {
  bucket = "fema-disaster-data"
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.storage_int}"
}


resource "google_pubsub_subscription_iam_member" "snowflake_pubsub_subscriber" {
  subscription = "fema-disaster_subscription"
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.notification_integration}"
}

resource "google_project_iam_member" "monitoring_viewer_access" {
  project = data.google_project.project.project_id
  role    = "roles/monitoring.viewer"

  member = "serviceAccount:${var.notification_integration}"
}


resource "snowflake_pipe" "fema_gcs_pipe" {
  database = "FEMA_DISASTER"
  schema   = "RAW"
  name     = "FEMA_PIPE"

  auto_ingest = true
  integration = "FEMA_NOTIFICATION_INT"

  depends_on = [
    google_pubsub_subscription_iam_member.snowflake_pubsub_subscriber,
    google_project_iam_member.monitoring_viewer_access
  ]

  # SQL Logic (Wrapped in a heredoc block)
  copy_statement = <<EOT
    COPY INTO fema_disaster.raw.fema_intervention
    FROM (
      SELECT
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS ingestion_time,
        METADATA$FILENAME AS src_file,
        $1 AS payload
      FROM @fema_disaster.raw.fema_disaster_stage
      (FILE_FORMAT => 'fema_disaster.raw.fema_file_format', PATTERN => '.*fema_disaster.*\\.json')
    )
  EOT
}
