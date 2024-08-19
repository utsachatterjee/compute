locals {
  sqlwshs = var.sqlwshs
}

# ------------------------------------------------------------------------------
# serverless sql warehouse
# ------------------------------------------------------------------------------

resource "databricks_sql_endpoint" "sqlwsh" {
  for_each                  = local.sqlwshs
  name                      = each.value.name
  cluster_size              = each.value.cluster_size
  enable_serverless_compute = each.value.enable_serverless_compute
  auto_stop_mins            = each.value.auto_stop_mins
  tags {
    dynamic "custom_tags" {
      for_each = toset(each.value.sqlwsh_tags)
      content {
        key   = custom_tags.value.key
        value = custom_tags.value.value
      }
    }
  }
}

resource "databricks_permissions" "clusterpermission" {
  for_each        = local.sqlwshs
  sql_endpoint_id = databricks_sql_endpoint.sqlwsh[each.key].id
  dynamic "access_control" {
    for_each = each.value.CAN_USE
    content {
      group_name       = access_control.value
      permission_level = "CAN_USE"
    }
  }
  dynamic "access_control" {
    for_each = each.value.CAN_MANAGE == null ? [] : each.value.CAN_MANAGE
    content {
      group_name       = access_control.value
      permission_level = "CAN_MANAGE"
    }
  }
}
