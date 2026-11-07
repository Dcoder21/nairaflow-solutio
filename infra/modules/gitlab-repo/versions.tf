terraform {
  required_version = ">= 1.8"
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 19.5"
    }
  }
}
