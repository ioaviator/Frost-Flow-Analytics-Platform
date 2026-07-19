
resource "snowflake_database" "fema_db" {
  name = "FEMA_DISASTER"
}

resource "snowflake_schema" "fema_schema" {
  name     = "RAW"
  database = snowflake_database.fema_db.name
}

resource "snowflake_table" "fema_table" {
  database                    = snowflake_schema.fema_schema.database
  schema                      = snowflake_schema.fema_schema.name
  name                        = "FEMA_INTERVENTION"
  change_tracking             = false
  depends_on = [ snowflake_database.fema_db, snowflake_schema.fema_schema ]
  
  column {
    name     = "ingestion_time"
    type     = "TIMESTAMP_NTZ"
    nullable = true
  }

  column {
    name     = "src_file"
    type     = "STRING"
    nullable = true
  }

  column {
    name     = "payload"
    type     = "VARIANT"
    nullable = false
  }
}

resource "snowflake_storage_integration_gcs" "fema_storage_int" {
  name                      = "FEMA_STORAGE_INT"
  enabled                   = true
  storage_allowed_locations = ["gcs://frost-flow-data/"]
}


resource "snowflake_stage_external_gcs" "fema_stage" {
  name                = "FEMA_DISASTER_STAGE"
  database            = snowflake_database.fema_db.name
  schema              = snowflake_schema.fema_schema.name
  url                 = "gcs://frost-flow-data/"
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
  name    = "FEMA_NOTIFICATION_INT_V2"
  enabled = true
  comment = "Notification integration created by Terraform"
  
  notification_provider        = "GCP_PUBSUB"
  gcp_pubsub_subscription_name = "projects/project-id/subscriptions/frost-flow_subscription"

  lifecycle {
    create_before_destroy = false
  }
}


resource "snowflake_pipe" "fema_gcs_pipe" {
  database = snowflake_database.fema_db.name
  schema   = snowflake_schema.fema_schema.name
  name     = "FEMA_PIPE"

  auto_ingest = true
  integration = snowflake_notification_integration.fema_notify_int.name
  
  depends_on = [ snowflake_notification_integration.fema_notify_int ]

  # SQL Logic (Wrapped in a heredoc block for clean formatting)
  copy_statement = <<EOT
    COPY INTO fema_disaster.raw.fema_intervention
    FROM (
      SELECT
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS ingestion_time,
        METADATA$FILENAME AS src_file,
        $1 AS payload
      FROM @fema_disaster.raw.fema_disaster_stage
      (FILE_FORMAT => 'fema_disaster.raw.fema_file_format', PATTERN => '.*frost_flow\\.json')
    )
  EOT
}
