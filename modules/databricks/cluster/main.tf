locals {
  clusters   = var.clusters
}

# ------------------------------------------------------------------------------
# Fetch policy ids
# ------------------------------------------------------------------------------
data "databricks_cluster_policy" "powerUser" {
  name = "Power User Compute"
}

data "databricks_cluster_policy" "jobCompute" {
  name = "Job Compute"
}

data "databricks_cluster_policy" "legacySharedCompute" {
  name = "Legacy Shared Compute"
}

data "databricks_cluster_policy" "personalCompute" {
  name = "Personal Compute"
}

data "databricks_cluster_policy" "sharedCompute" {
  name = "Shared Compute"
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

# ------------------------------------------------------------------------------
# Create Cluster
# ------------------------------------------------------------------------------
resource "databricks_cluster" "clusters" {
  for_each      = local.clusters
  cluster_name  = each.value.name
  spark_version = each.value.spark_version_id == "" ? data.databricks_spark_version.latest_lts.id : each.value.spark_version_id
  node_type_id  = each.value.instance_pool_id_req == false ? each.value.node_type_id : null
  instance_pool_id = each.value.instance_pool_id_req == false ? null : each.value.poolid
  num_workers   = each.value.num_workers
  dynamic "autoscale" {
    for_each =  each.value.autoscale_required == true ? [1]: []
    content {
      min_workers = each.value.autoscale_min_workers
      max_workers = each.value.autoscale_max_workers
    }
  }
  spark_conf              = tomap(each.value.spark_conf)
  runtime_engine          = each.value.runtime_engine
  data_security_mode      = each.value.data_security_mode
  autotermination_minutes = each.value.autotermination_minutes
  azure_attributes {
    availability       = each.value.availability
    first_on_demand    = each.value.first_on_demand
    spot_bid_max_price = each.value.spot_bid_max_price
  }
  enable_local_disk_encryption = each.value.enable_local_disk_encryption
  enable_elastic_disk          = each.value.enable_elastic_disk
  custom_tags                  = each.value.tag_required == true ? each.value.tags : {}
  dynamic "library" {
    for_each = each.value.maven_lib_required == true ? toset(each.value.maven_lib) : []
    content {
      maven {
        coordinates = library.value
      }
    }
  }
  dynamic "library" {
    for_each = each.value.pypi_lib_required == true ? toset(each.value.pypi_lib) : []
    content {
      pypi {
        package = library.value
      }
    }
  }
}

resource "databricks_permissions" "clusterpermission" {
  for_each   = local.clusters
  cluster_id = databricks_cluster.clusters[each.key].id
  dynamic "access_control" {
    for_each = each.value.CAN_RESTART == null ? [] : each.value.CAN_RESTART
    content {
      group_name = access_control.value
      permission_level = "CAN_RESTART"
    }
  }
  dynamic "access_control" {
    for_each = each.value.CAN_MANAGE == null ? [] : each.value.CAN_MANAGE
    content {
      group_name = access_control.value
      permission_level = "CAN_MANAGE"
    }
  }
  depends_on = [ databricks_cluster.clusters ]
}