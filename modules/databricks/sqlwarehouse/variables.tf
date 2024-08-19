variable "sqlwshs" {
  description = "A map to create multiple warehouses"
  type = map(object({
    name                      = string
    cluster_size              = string
    enable_serverless_compute = bool
    auto_stop_mins            = number
    sqlwsh_tags = set(object({
      key   = string
      value = string
    }))
    CAN_USE    = optional(list(string))
    CAN_MANAGE = optional(list(string))
  }))
}

variable "workspace_url" {
  description = "URL of workspace where cluster is to be created"
  type        = string
  nullable    = false
}
