variable "name" {
  type        = string
  description = "Repository name."
}

variable "namespace_id" {
  type        = number
  description = "ID of the GitLab group the repo lives in."
}

variable "description" {
  type        = string
  default     = ""
  description = "Repository description."
}

variable "visibility_level" {
  type        = string
  default     = "private"
  description = "private, internal or public. Policy only allows private."
}
