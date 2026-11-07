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
  project          = gitlab_project.this.id
  branch           = "main"
  allow_force_push = false

  # Newer GitLab provider versions use these blocks instead of
  # push_access_level / merge_access_level.
  allowed_to_push {
    access_level = "no one"
  }
  allowed_to_merge {
    access_level = "maintainer"
  }
}
