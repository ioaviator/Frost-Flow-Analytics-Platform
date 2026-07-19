
resource "snowflake_database" "fema" {
  name = "FEMA_DISASTER"
}

resource "snowflake_schema" "schema" {
  name     = "RAW"
  database = snowflake_database.fema.name
}

resource "snowflake_storage_integration_gcs" "fema_storage_int" {
  name                      = "FEMA_STORAGE_INT"
  enabled                   = true
  storage_allowed_locations = ["gcs://frost-flow-data/"]
}