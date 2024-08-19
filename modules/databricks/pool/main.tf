locals {
  pools = var.pools
}

# ------------------------------------------------------------------------------
# Pool 
# ------------------------------------------------------------------------------

resource "databricks_instance_pool" "pools" {
  for_each                 = local.pools
  instance_pool_name       = each.value.name
  min_idle_instances       = each.value.min_idle_instances
  max_capacity             = each.value.max_capacity
  node_type_id             = each.value.node_type_id
  preloaded_spark_versions = [each.value.spark_version]
  azure_attributes {
    availability = each.value.availability
  }
  idle_instance_autotermination_minutes = each.value.autotermination_minutes
  enable_elastic_disk                   = each.value.enable_elastic_disk
  custom_tags                           = each.value.tag_required == true ? each.value.tags : {}
}