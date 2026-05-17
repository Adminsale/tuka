output "app_url" {
  description = "Application base URL"
  value       = "http://localhost:${var.app_port}"
}

output "prometheus_url" {
  description = "Prometheus UI URL"
  value       = "http://localhost:9090"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://localhost:3000"
}

output "alertmanager_url" {
  description = "Alertmanager UI URL"
  value       = "http://localhost:9093"
}

output "network_id" {
  description = "Docker network ID used by all containers"
  value       = docker_network.sre.id
}
