variable "name" {
  type        = string
  description = "Namespace name, e.g. nairaflow-dev."
}

variable "env" {
  type        = string
  description = "Environment: dev, staging or prod."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be dev, staging or prod."
  }
}

variable "owner" {
  type        = string
  description = "Team that owns the namespace."
}

variable "cost_centre" {
  type        = string
  description = "Cost centre the namespace is billed to."
}

variable "quota" {
  type = object({
    cpu    = string
    memory = string
    pods   = string
  })
  default     = null
  description = "Resource quota. Required by policy for prod."
}

variable "allow_from_namespaces" {
  type        = list(string)
  default     = ["envoy-gateway-system", "istio-system"]
  description = "Namespaces allowed to send traffic in (the gateway and the mesh)."
}

variable "extra_ingress_cidrs" {
  type = list(object({
    cidr = string
    port = number
  }))
  default     = []
  description = "Extra IP ranges allowed in. Policy blocks 0.0.0.0/0 on admin ports."
}
