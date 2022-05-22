# Consul + Nomad + Fabio + Tailscale

Features:
* Nomad + Consul integration enabled
* Fabio + Consul integration enabled
* You can deploy your HTTP service in multiple instances via Nomad, and it will automatically have a load balancer via Fabio
* All UIs and management stuff is exposed only to private Tailscale network

Networking:
* Fabio LB: 0.0.0.0:80
* Fabio UI: <tailscale_ip>:9998
* Consul UI: <tailscale_ip>:8500
* Nomad UI:<tailscale_ip>:4646

## Getting started

Disclaimer: I am not a professional system administrator, so there might be some hacks that you don't like.

Requirements:
* Domain (you can buy one on [Namecheap](https://namecheap.com))
* 3 VMs in any cloud with public IPs with Ubuntu 22.04 (you can buy one on Digital Ocean)
* DNS hosting (Digital Ocean has DNS hosting integrated)
* [Tailscale](https://tailscale.com) account (you can easily create one)
* Ansible installed on your laptop
* Consul installed on your laptop

1. `git clone && cd ..`
2. Add A records, so your VMs will be available via domain name like this: `lux-1.<your_domain>`, `lux-2.<your_domain>`, `lux-3.<your_domain>`
   * I had VMs based in Lux, so I am using `lux-x` domain prefixes in this manual. If you want to use another DC name just replace `lux` everywhere
3. Add them to your Ansible hosts file like this:

```
$ cat /etc/ansible/hosts
[lux]
lux-1.<your_domain>
lux-2.<your_domain>
lux-3.<your_domain>
```

4. Generate Tailscale key to authenticate your VMs (https://login.tailscale.com/admin/settings/keys => 'Auth keys' => 'Generate auth key' => 'Reusable' => 'Generate key')
5. Set `TAILSCALE_TOKEN` env on your laptop so Ansible can use it in future
6. Run `consul keygen` on your laptop and put this key into `CONSUL_ENCRYPT` env (for Ansible too)
7. Run `consul tls ca create` and copy resulting files into `./consul-keys`
8. Run `consul tls cert create -server -dc lux -domain consul` and copy resulting files into `./consul-keys`
9. Check that you have the following files available:

```
$ ls -la consul-keys/
-rw-------  1 bk staff  227 May 22 19:44 consul-agent-ca-key.pem
-rw-r--r--  1 bk staff 1078 May 22 19:44 consul-agent-ca.pem
-rw-------  1 bk staff  227 May 22 19:44 lux-server-consul-0-key.pem
-rw-r--r--  1 bk staff  969 May 22 19:44 lux-server-consul-0.pem
```

10. Run `ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook tailscale.yaml docker.yaml hashistack.yaml fabio.yaml`

## Job example

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
      tags = ["urlprefix-<your_domain>/"]
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