locals {
  artifact_allow_list_maven = var.artifact_allow_list_maven
  environment               = var.environment
  sbx                       = startswith(upper(local.environment), "SBX")
}

# ------------------------------------------------------------------------------
# ADD library to allowlist in UC
# ------------------------------------------------------------------------------

resource "databricks_artifact_allowlist" "maven" {
  count         = local.sbx == true ? 1 : 0
  artifact_type = "LIBRARY_MAVEN"
  dynamic "artifact_matcher" {
    for_each = toset(local.artifact_allow_list_maven)
    content {
      artifact   = artifact_matcher.value
      match_type = "PREFIX_MATCH"
    }
  }
}