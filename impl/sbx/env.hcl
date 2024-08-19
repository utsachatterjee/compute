# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.

locals {

  #----------------------------------------------------------
  # ASSEMBLE THE NAMES OF THINGS
  #----------------------------------------------------------

  application_name = "databricks"
  application      = "dbk"
  environment      = "sbx"
  rev              = "00"
  env              = upper("${local.environment}")

  #----------------------------------------------------------
  # TERRAGRUNT STATE
  #----------------------------------------------------------

  subscription_id                        = ""
  deployment_storage_resource_group_name = "<resouregroupname>"
  deployment_storage_account_name        = "<storageaccountname>"
  deployment_storage_container           = "<comtainername>"
  git_branch                             = local.git_branch_tmp == "HEAD" ? get_env("BRANCH_NAME") : local.git_branch_tmp
  base_name                              = "<uniquename for your corporation>"

  # -----------------------------------------------------------
  # Workspace Input Parameters
  # ----------------------------------------------------------- 
  workspace_url = "URL"

  # -----------------------------------------------------------
  # Cluster
  # -----------------------------------------------------------

  clusters = {
    cluster1 = {
      name                    = "ClusterUtsa"
      spark_version_id        = ""
      num_workers             = 4
      instance_pool_id_req    = false
      node_type_id            = "Standard_E4d_v4",
      driver_node_type_id     = "Standard_E16d_v4"
      autoscale_required      = false
      autotermination_minutes = 10
      spark_conf : {
        "spark.databricks.delta.preview.enabled" : "true",
        "spark.databricks.sql.initial.catalog.name" : "finops"
      },
      data_security_mode           = "USER_ISOLATION"
      enable_local_disk_encryption = false
      enable_elastic_disk          = true
      pypi_lib_required            = true
      pypi_lib                     = [
        {
          libname = "oracledb"
          repo = "https://pypi.org/project/oracledb/"
        }
      ]
      maven_lib_required           = false
      tag_required                 = true
      tags = {
        "PythonUDF.enabled" : "true"
      }
      CAN_RESTART = ["databricks-account-group1", "databricks-account-group2"]
    }
  }

  # -----------------------------------------------------------
  # POOL
  # -----------------------------------------------------------
  pools = {
    pool1 = {
      name                    = "PoolUtsa"
      min_idle_instances      = "20"
      max_capacity            = "100"
      node_type_id            = "Standard_E4d_v4"
      spark_version           = "14.3.x-photon-scala2.12"
      availability            = "ON_DEMAND_AZURE"
      autotermination_minutes = 60
      enable_elastic_disk     = true
      tag_required            = false
      CAN_ATTACH_TO           = ["databricks-account-group1", "databricks-account-group2"]
    }
  }

  # -----------------------------------------------------------
  # SQL WAREHOUSE Type Unity Catalog
  # -----------------------------------------------------------
  sqlwshs = {
    sqlwsh1 = {
      name                      = "WarehouseUtsa"
      cluster_size              = "2X-Small"
      enable_serverless_compute = true
      auto_stop_mins            = 5
      sqlwsh_tags = [
        {
          key   = "terraform_managed"
          value = "true"
        }
      ]
      CAN_USE = ["databricks-account-group1", "databricks-account-group2"]
    }
  }
}
