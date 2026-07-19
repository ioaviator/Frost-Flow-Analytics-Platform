
resource "snowflake_database" "fema" {
  name = "fema_disaster"
}

resource "snowflake_schema" "schema" {
  name     = "raw"
  database = snowflake_database.fema.name
}