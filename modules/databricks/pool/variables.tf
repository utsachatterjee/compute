variable "workspace_url" {
  description = "URL of workspace where cluster is to be created"
  type        = string
  nullable    = false
}
variable "pools" {
  description = "A map to create multiple pools"
  type = map(object({
    name                    = string
    min_idle_instances      = string
    max_capacity            = string
    node_type_id            = string
    spark_version           = string
    availability            = string
    autotermination_minutes = number
    enable_elastic_disk     = bool
    tag_required            = bool
    tags                    = optional(map(any))
  }))
}