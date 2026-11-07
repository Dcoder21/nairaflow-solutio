output "id" {
  value       = gitlab_project.this.id
  description = "Project ID."
}

output "http_url" {
  value       = gitlab_project.this.http_url_to_repo
  description = "Clone URL."
}
