# Consul + Nomad + Fabio + Tailscale

Features:
* Nomad + Consul integration enabled
* Fabio + Consul integration enabled
* You can deploy your http service in multiple instances via Nomad and it will automatically have load balancer via Fabio
* All UIs and management stuff is exposed only to private tailscale network

Networking:
* Fabio LB: 0.0.0.0:80
* Fabio UI: <tailscale_ip>:9998
* Consul UI: <tailscale_ip>:8500
* Nomad UI:<tailscale_ip>:4646

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