variable "network_name" {
  description = "Docker network shared by all SRE services"
  type        = string
  default     = "sre-network"
}

variable "app_image" {
  description = "Docker image for the application (built and pushed by CI/CD)"
  type        = string
  default     = "ghcr.io/adminsale/tuka/sre-app:latest"
}

variable "app_port" {
  description = "Host port to expose the application on"
  type        = number
  default     = 5000
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}
