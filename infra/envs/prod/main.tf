terraform {
  required_version = ">= 1.8"
  backend "http" {}
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
  }
}

# Locally: export KUBE_CONFIG_PATH=~/.kube/config KUBE_CTX=kind-nairaflow
# In CI: uses the tofu-apply service account inside the cluster.
provider "kubernetes" {}

module "namespace" {
  source      = "../../modules/namespace"
  name        = "nairaflow-prod"
  env         = "prod"
  owner       = "platform-team"
  cost_centre = "payments"
  quota       = { cpu = "4", memory = "8Gi", pods = "50" }
}
