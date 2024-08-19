output "sqlwh_config" {
  description = "sql warehouse resource block output"
  value = {
    "NEW" : [databricks_sql_endpoint.sqlwsh]
  }
}

output "sqlwhNames" {
  description = "Outputs name list"
  value       = [for i in databricks_sql_endpoint.sqlwsh : i.name]
}