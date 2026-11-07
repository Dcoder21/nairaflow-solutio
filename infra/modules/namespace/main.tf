resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
    labels = {
      owner         = var.owner
      "cost-centre" = var.cost_centre
      env           = var.env
    }
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  count = var.quota == null ? 0 : 1

  metadata {
    name      = "default-quota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.quota.cpu
      "requests.memory" = var.quota.memory
      "pods"            = var.quota.pods
    }
  }
}

# Gives every container sensible defaults so the quota above can be enforced.
resource "kubernetes_limit_range_v1" "this" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    limit {
      type            = "Container"
      default         = { cpu = "500m", memory = "512Mi" }
      default_request = { cpu = "100m", memory = "128Mi" }
    }
  }
}

# Only pods in the same namespace, the gateway and the mesh may connect in.
resource "kubernetes_network_policy_v1" "ingress" {
  metadata {
    name      = "allow-trusted-ingress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {}
      }
      dynamic "from" {
        for_each = var.allow_from_namespaces
        content {
          namespace_selector {
            match_labels = { "kubernetes.io/metadata.name" = from.value }
          }
        }
      }
    }

    dynamic "ingress" {
      for_each = var.extra_ingress_cidrs
      content {
        from {
          ip_block {
            cidr = ingress.value.cidr
          }
        }
        ports {
          port     = tostring(ingress.value.port)
          protocol = "TCP"
        }
      }
    }
  }
}
