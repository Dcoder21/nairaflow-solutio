terraform {
  required_version = ">= 1.8"
  backend "http" {}
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = ">= 17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
  }
}

# Reads GITLAB_TOKEN from the environment (a personal access token with api scope).
provider "gitlab" {}
provider "kubernetes" {}

variable "group_path" {
  type        = string
  description = "Your GitLab group path, e.g. nairaflow-yourname."
}

data "gitlab_group" "nairaflow" {
  full_path = var.group_path
}

# The GitOps config repo Argo CD will read from on day 11.
module "config_repo" {
  source       = "../../modules/gitlab-repo"
  name         = "nairaflow-config"
  namespace_id = tonumber(data.gitlab_group.nairaflow.id)
  description  = "Desired state for the NairaFlow cluster (read by Argo CD)."
}
