# Consul + Nomad + Fabio + Tailscale

## Example of bogdi blog job to be publicly available via fabio

```hcl
job "webserver" {
  datacenters = ["lux"]
  type = "service"

  group "webserver" {
    count = 3
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "bogdi-blog-service"
      tags = ["urlprefix-bogdi.xyz/"]
      port = "http"
      check {
        name     = "alive"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    task "bogdi-blog-container" {
      driver = "docker"
      config {
        image = "ghcr.io/gofort/bogdi:d34c45c5e241c302aa27988f5eb0c70fee637bff"
        ports = ["http"]
      }
    }
  }
}
```