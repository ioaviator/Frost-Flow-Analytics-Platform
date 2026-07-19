
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