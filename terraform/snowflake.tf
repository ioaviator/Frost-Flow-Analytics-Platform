
resource "snowflake_database" "fema_db" {
  name = "FEMA_DISASTER"
}

resource "snowflake_schema" "fema_schema" {
  name     = "RAW"
  database = snowflake_database.fema_db.name
}

resource "snowflake_table" "fema_table" {
  database        = snowflake_schema.fema_schema.database
  schema          = snowflake_schema.fema_schema.name
  name            = "FEMA_INTERVENTION"
  change_tracking = false
  depends_on      = [snowflake_database.fema_db, snowflake_schema.fema_schema]

  column {
    name     = "INGESTION_TIME"
    type     = "TIMESTAMP_NTZ"
    nullable = true
  }

  column {
    name     = "SRC_FILE"
    type     = "STRING"
    nullable = true
  }

  column {
    name     = "PAYLOAD"
    type     = "VARIANT"
    nullable = false
  }
}

resource "snowflake_storage_integration_gcs" "fema_storage_int" {
  name                      = "FEMA_STORAGE_INT"
  enabled                   = true
  depends_on                = [google_storage_bucket.fema_disaster_bucket]
  storage_allowed_locations = [replace(data.google_storage_bucket.fema_disaster_bkt.url, "gs://", "gcs://")]
}


resource "snowflake_stage_external_gcs" "fema_stage" {
  name                = "FEMA_DISASTER_STAGE"
  database            = snowflake_database.fema_db.name
  schema              = snowflake_schema.fema_schema.name
  depends_on          = [google_storage_bucket.fema_disaster_bucket]
  url                 = replace(data.google_storage_bucket.fema_disaster_bkt.url, "gs://", "gcs://")
  storage_integration = snowflake_storage_integration_gcs.fema_storage_int.name

  encryption {
    none {}
  }
}


resource "snowflake_file_format" "fema_file_format" {
  name        = "FEMA_FILE_FORMAT"
  database    = snowflake_database.fema_db.name
  schema      = snowflake_schema.fema_schema.name
  format_type = "JSON"
}

resource "snowflake_notification_integration" "fema_notify_int" {
  name    = "FEMA_NOTIFICATION_INT"
  enabled = true
  comment = "Notification integration created by Terraform"

  notification_provider        = "GCP_PUBSUB"
  gcp_pubsub_subscription_name = "projects/${data.google_project.project.project_id}/subscriptions/fema-disaster_subscription"

  lifecycle {
    create_before_destroy = false
  }
}
