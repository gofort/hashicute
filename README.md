# Hashicute

These are Ansible playbooks to configure a computing cluster consisting of the following tools:

* Tailscale (VPN)
* Consul (Service Mesh)
* Nomad (Orchestrator)
* Docker (Containers)
* Traefik (Load Balancer)
* Prometheus (Metrics)

## Features

* Nomad + Consul + Traefik are integrated out of the box
* Forwarding Consul DNS (you can resolve your services using dig on any VM like this: `dig consul.service.lux.consul. ANY`)
* All UIs and management stuff are exposed only to private Tailscale network
* Traefik Load Balancer is listening to public IPs so you can access your services from the internet if you need
* Only 1 DC mode is supported

## Networking

* Traefik LB: <public_ip-of-your-vm>:80
* Traefik UI: <tailscale_ip-of-your-vm>:8081
* Consul UI: <tailscale_ip-of-your-vm>:8500
* Nomad UI: <tailscale_ip-of-your-vm>:4646
* Prometheus UI: <tailscale_ip-of-your-vm>:80/prometheus

## Requirements

* Domain (you can buy one on [Namecheap](https://namecheap.com))
* 3 VMs in any cloud with public IPs with Ubuntu 22.04 (you can buy one on [G-Core Labs](https://gcorelabs.com))
* DNS hosting ([G-Core Labs](https://gcorelabs.com) has DNS hosting integrated)
* [Tailscale](https://tailscale.com) account (you can easily create one)
* [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-specific-operating-systems) installed on your laptop
* [Consul](https://www.consul.io/downloads) installed on your laptop

## Getting started

1. `git clone && cd ..`
2. Add A records, so your VMs will be available via domain name like this: `lux-1.<your_domain>`, `lux-2.<your_domain>`, `lux-3.<your_domain>`
   * I had VMs based in Lux, so I am using `lux-x` domain prefixes in this manual. If you want to use another DC name, replace `lux` everywhere.
3. Add them to your Ansible hosts file like this:

```
$ cat /etc/ansible/hosts
[lux]
lux-1.<your_domain>
lux-2.<your_domain>
lux-3.<your_domain>
```

4. Configure the ssh client on your laptop

```
$ cat .ssh/config
Host *.<your_domain>
  Port 22
  User ubuntu
  ForwardAgent yes
```

5. Generate Tailscale key to authenticate your VMs (https://login.tailscale.com/admin/settings/keys => 'Auth keys' => 'Generate auth key' => 'Reusable' => 'Generate key')
6. Set `TAILSCALE_TOKEN` env on your laptop so Ansible can use it in future
7. Run `consul keygen` on your laptop and put this key into `CONSUL_ENCRYPT` env (for Ansible too)
8. Run `consul tls ca create` and copy resulting files into `./consul-keys`
9.  Run `consul tls cert create -server -dc lux -domain consul` and copy resulting files into `./consul-keys`
10. Check that you have the following files available:

```
$ ls -la consul-keys/
-rw-------  1 bk staff  227 May 22 19:44 consul-agent-ca-key.pem
-rw-r--r--  1 bk staff 1078 May 22 19:44 consul-agent-ca.pem
-rw-------  1 bk staff  227 May 22 19:44 lux-server-consul-0-key.pem
-rw-r--r--  1 bk staff  969 May 22 19:44 lux-server-consul-0.pem
```

11. Run `ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook upgrade.yaml tailscale.yaml docker.yaml hashistack.yaml ans-traefik-exp.yaml ans-prometheus.yaml`
12. Open Nomad UI (<tailscale_ip-of-your-vm>:4646) and run the following job there:

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
      name = "apache-webserver"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=Host(`mydomain.xyz`)",
        "traefik.http.routers.prometheus-ui.entrypoints=http"
      ]
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

    task "apache" {
      driver = "docker"
      config {
        image = "httpd:latest"
        ports = ["http"]
      }
    }
  }
}
```

13. Run `curl -I --header "Host: mydomain.xyz" http://<public-ip-of-your-vm>`
14. You are awesome!

## Prometheus Metrics Scraping

Just add tag "metrics" to scrape metrics using `/metrics` path.

```hcl
service {
  name = "traefik-exp"
  port = "api"

  tags = ["metrics"]
}
```