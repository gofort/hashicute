job "prometheus" {
  datacenters = ["lux"]
  type        = "service"

  group "monitoring" {
    count = 1

    network {
      port "prometheus_ui" {
        static = 9090
        host_network = "private"
      }
    }

    restart {
      attempts = 5
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 800
    }

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

scrape_configs:

  - job_name: 'nomad_metrics'

    consul_sd_configs:
    - server: '{{ env "CONSUL_HTTP_ADDR" }}'
      services: ['nomad-client', 'nomad']

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep

    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'consul-services'

    consul_sd_configs:
    - server: '{{ env "CONSUL_HTTP_ADDR" }}'

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)metrics(.*)'
      action: keep

    scrape_interval: 5s
    metrics_path: /metrics
    params:
      format: ['prometheus']

EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]

        ports = ["prometheus_ui"]
      }

      service {
        name = "prometheus"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus-ui.rule=PathPrefix(`/prometheus`)",
          "traefik.http.routers.prometheus-ui.entrypoints=http-internal",
          "traefik.http.routers.prometheus-ui.middlewares=prometheus-stripprefix",
          "traefik.http.middlewares.prometheus-stripprefix.stripprefix.prefixes=/prometheus"
        ]
        
        port = "prometheus_ui"

        check {
          name     = "prometheus_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}