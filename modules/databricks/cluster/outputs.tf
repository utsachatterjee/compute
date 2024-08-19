output "cluster_config" {
  description = "Cluster resource block output"
  value = {
    "Clusters" : [databricks_cluster.clusters]
    "Permission" : [databricks_permissions.clusterpermission]
  }
} 