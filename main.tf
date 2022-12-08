terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "ubuntu_ssh" {
  name = "ubuntu_ssh"
}

data "digitalocean_project" "lab_project" {
  name = "first-project"
}

resource "digitalocean_tag" "do_tag" {
  name = "frontend_A01201759"
}

resource "digitalocean_tag" "new_tag"{
  name = "application_A01201759"
}

resource "digitalocean_vpc" "web_vpc" {
  name   = "firstproject"
  region = var.region
  ip_range = var.ip_range
}

#create a new web droplet in the sfo3 region

resource "digitalocean_droplet" "web" {
  image    = var.image_default
  name     = "application-A01201759"
  tags     = [digitalocean_tag.new_tag.id]
  region   = var.region
  size     = "s-1vcpu-512mb-10gb"
  vpc_uuid = digitalocean_vpc.web_vpc.id
  ssh_keys = [data.digitalocean_ssh_key.ubuntu_ssh.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_droplet" "webnew" {
  image    = var.image_default
  name     = "frontend-A01201759"
  tags     = [digitalocean_tag.do_tag.id]
  region   = var.region
  size     = "s-1vcpu-512mb-10gb"
  vpc_uuid = digitalocean_vpc.web_vpc.id
  ssh_keys = [data.digitalocean_ssh_key.ubuntu_ssh.id]

  lifecycle {
    create_before_destroy = true
  }
}

# adding firewall

resource "digitalocean_firewall" "webnew" {
  name = "frontfirewall"
  droplet_ids = digitalocean_droplet.web.*.id

# SSH is allowed from public internet

  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

# HTTP is allowed to frontend from the public internet

  inbound_rule {
    protocol = "tcp"
    port_range = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
    }

# ICMP is allowed to both system from all sources

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

# HTTP proxy traffic allowance

  inbound_rule {
    protocol = "tcp"
    port_range = 80
    source_addresses = [digitalocean_droplet.web.id]
  }

  outbound_rule {
    protocol = "tcp"
    port_range = 80
    destination_addresses = [digitalocean_droplet.webnew.id]
  }
}

resource "digitalocean_firewall" "web" {
  name = "appfirewall"
  droplet_ids = digitalocean_droplet.web.*.id


  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }


  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }


  inbound_rule {
    protocol = "tcp"
    port_range = 80
    source_addresses = [digitalocean_droplet.webnew.id]
  }

  outbound_rule {
    protocol = "tcp"
    port_range = 80
    destination_addresses = [digitalocean_droplet.web.id]
  }
}


# adds the droplets to an existing project
# the flatten will allow you to make a 2d list of the droplets so it isn't an array of arrays
resource "digitalocean_project_resources" "project_attach" {
  project   = data.digitalocean_project.lab_project.id
  resources = flatten([digitalocean_droplet.web.*.urn])
}

# reads out the IP of the servers
output "server_ip" {
  value = digitalocean_droplet.web.*.ipv4_address
}
