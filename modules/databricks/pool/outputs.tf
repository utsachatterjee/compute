output "pool_config" {
  description = "Pool resource block output"
  value = {
    "uc_pool_id" : databricks_instance_pool.pools["pool1"].id
  }
}

output "poolNames" {
  value = [for i in databricks_instance_pool.pools : i.instance_pool_name]
}
