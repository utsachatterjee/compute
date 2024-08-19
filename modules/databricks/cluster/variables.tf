variable "workspace_url" {
  description = "URL of workspace where cluster is to be created"
  type        = string
  nullable    = false
}

variable "clusters" {
  description = "A map to create multiple clusters"
  type = map(object({
    name                         = string
    instance_pool_id_req         = bool
    spark_version_id             = optional(string)
    node_type_id                 = optional(string)
    driver_node_type_id          = optional(string)
    num_workers                  = optional(number)
    autoscale_required           = bool
    autoscale_min_workers        = optional(number)
    autoscale_max_workers        = optional(number)
    autotermination_minutes      = number
    spark_conf                   = optional(map(any))
    data_security_mode           = optional(string)
    runtime_engine               = optional(string)
    availability                 = optional(string)
    first_on_demand              = optional(number)
    spot_bid_max_price           = optional(string)
    enable_local_disk_encryption = optional(bool)
    enable_elastic_disk          = optional(bool)
    maven_lib_required           = optional(bool)
    maven_lib                    = optional(list(string))
    pypi_lib_required            = optional(bool)
    pypi_lib                     = optional(list(object({
      libname = string
      repo = string
    })))
    tag_required                 = bool
    tags                         = optional(map(any))
    CAN_RESTART                  = optional(list(string))
    CAN_MANAGE                   = optional(list(string))
  }))
}
