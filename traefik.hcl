job "traefik-exp" {
  datacenters = ["lux"]
  type        = "system"

  group "traefik-exp" {
    count = 1

    network {
      port "http" {
        static = 80
        host_network = "public"
      }

      port "http-internal" {
        static = 80
        host_network = "private"
      }

      port "api" {
        static = 8081
        host_network = "private"
      }
    }

    service {
      name = "traefik-exp"
      port = "api"

      tags = ["metrics"]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik-exp" {
      driver = "docker"

      config {
        image        = "traefik:latest"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }

      template {
        data = <<EOF
[entryPoints]
    [entryPoints.http]
    address = "{{ env "NOMAD_IP_http" }}:80"
    [entryPoints.http-internal]
    address = "{{ env "NOMAD_IP_api" }}:80"
    [entryPoints.traefik]
    address = "{{ env "NOMAD_IP_api" }}:8081"

[metrics]
  [metrics.prometheus]

[api]
    dashboard = true
    insecure  = true

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "{{ env "CONSUL_HTTP_ADDR" }}"
      scheme  = "http"
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}