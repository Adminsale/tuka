terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.5.0"

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "docker" {}

resource "docker_network" "sre" {
  name = var.network_name
}

# ── Application ────────────────────────────────────────────────────────────────

resource "docker_image" "app" {
  name         = var.app_image
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "sre-app"
  image = docker_image.app.image_id

  networks_advanced {
    name = docker_network.sre.name
  }

  ports {
    internal = 5000
    external = var.app_port
  }

  env = ["FLASK_ENV=production"]

  healthcheck {
    test         = ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "10s"
  }

  restart = "unless-stopped"
}

# ── Prometheus ─────────────────────────────────────────────────────────────────

resource "docker_image" "prometheus" {
  name         = "prom/prometheus:v2.51.0"
  keep_locally = true
}

resource "docker_container" "prometheus" {
  name  = "sre-prometheus"
  image = docker_image.prometheus.image_id

  networks_advanced {
    name = docker_network.sre.name
  }

  ports {
    internal = 9090
    external = 9090
  }

  volumes {
    host_path      = abspath("${path.module}/../monitoring/prometheus/prometheus.yml")
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }

  volumes {
    host_path      = abspath("${path.module}/../monitoring/prometheus/alert.rules.yml")
    container_path = "/etc/prometheus/alert.rules.yml"
    read_only      = true
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=15d",
    "--web.enable-lifecycle",
  ]

  restart = "unless-stopped"
}

# ── Alertmanager ───────────────────────────────────────────────────────────────

resource "docker_image" "alertmanager" {
  name         = "prom/alertmanager:v0.27.0"
  keep_locally = true
}

resource "docker_container" "alertmanager" {
  name  = "sre-alertmanager"
  image = docker_image.alertmanager.image_id

  networks_advanced {
    name = docker_network.sre.name
  }

  ports {
    internal = 9093
    external = 9093
  }

  volumes {
    host_path      = abspath("${path.module}/../monitoring/prometheus/alertmanager.yml")
    container_path = "/etc/alertmanager/alertmanager.yml"
    read_only      = true
  }

  restart = "unless-stopped"
}

# ── Grafana ────────────────────────────────────────────────────────────────────

resource "docker_image" "grafana" {
  name         = "grafana/grafana:10.4.0"
  keep_locally = true
}

resource "docker_container" "grafana" {
  name  = "sre-grafana"
  image = docker_image.grafana.image_id

  networks_advanced {
    name = docker_network.sre.name
  }

  ports {
    internal = 3000
    external = 3000
  }

  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_password}",
    "GF_USERS_ALLOW_SIGN_UP=false",
    "GF_AUTH_ANONYMOUS_ENABLED=false",
  ]

  volumes {
    host_path      = abspath("${path.module}/../monitoring/grafana/provisioning")
    container_path = "/etc/grafana/provisioning"
    read_only      = true
  }

  volumes {
    host_path      = abspath("${path.module}/../monitoring/grafana/dashboards")
    container_path = "/var/lib/grafana/dashboards"
    read_only      = true
  }

  restart = "unless-stopped"

  depends_on = [docker_container.prometheus]
}
