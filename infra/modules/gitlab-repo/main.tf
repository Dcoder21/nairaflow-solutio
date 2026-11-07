resource "gitlab_project" "this" {
  name                                  = var.name
  namespace_id                          = var.namespace_id
  description                           = var.description
  visibility_level                      = var.visibility_level
  initialize_with_readme                = true
  only_allow_merge_if_pipeline_succeeds = true
  remove_source_branch_after_merge      = true
}

resource "gitlab_branch_protection" "main" {
  project            = gitlab_project.this.id
  branch             = "main"
  push_access_level  = "no one"
  merge_access_level = "maintainer"
  allow_force_push   = false
}
