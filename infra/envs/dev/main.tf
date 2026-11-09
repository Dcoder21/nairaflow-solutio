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
  name        = "nairaflow-dev"
  env         = "dev"
  owner       = "platform-team"
  cost_centre = "payments"
  quota       = { cpu = "2", memory = "4Gi", pods = "30" }

  # Day 10: the CloudNativePG operator must reach the database pods to manage them.
  allow_from_namespaces = ["envoy-gateway-system", "istio-system", "cnpg-system"]
}
