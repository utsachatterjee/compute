variable "workspace_url" {
  description = "URL of workspace"
  type        = string
  nullable    = false
}

variable "artifact_allow_list_maven" {
  type     = list(string)
  nullable = true
}

variable "environment" {
  type     = string
  nullable = false
}