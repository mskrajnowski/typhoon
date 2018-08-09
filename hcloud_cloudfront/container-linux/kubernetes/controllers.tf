# Controller Instance DNS records
resource "cloudflare_record" "controllers" {
  count = "${var.controller_count}"

  # DNS zone where record should be created
  domain = "${var.dns_zone}"

  # DNS record (will be prepended to domain)
  name = "${var.cluster_name}"
  type = "A"
  ttl  = 300

  # IPv4 addresses of controllers
  value = "${element(hcloud_server.controllers.*.ipv4_address, count.index)}"
}

# Discrete DNS records for each controller's private IPv4 for etcd usage
resource "cloudflare_record" "etcds" {
  count = "${var.controller_count}"

  # DNS zone where record should be created
  domain = "${var.dns_zone}"

  # DNS record (will be prepended to domain)
  name = "${var.cluster_name}-etcd${count.index}"
  type = "A"
  ttl  = 300

  # private IPv4 address for etcd
  value = "${element(hcloud_server.controllers.*.ipv4_address, count.index)}"
}

# Controller droplet instances
resource "hcloud_server" "controllers" {
  count = "${var.controller_count}"

  name     = "${var.cluster_name}-controller-${count.index}"
  location = "${var.location}"

  image       = "${var.image}"
  server_type = "${var.controller_type}"

  rescue   = "linux64"
  ssh_keys = ["${hcloud_ssh_key.key.*.name}"]

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /mnt/oem /mnt/boot /mnt/root",
      "mount /dev/sda1 /mnt/boot",
      "mount /dev/sda6 /mnt/oem",
      "mount /dev/sda9 /mnt/root",
      "touch /mnt/boot/coreos/first_boot",
      "mkdir -p /mnt/root/etc/metadata",
    ]
  }

  provisioner "file" {
    content     = "${element(data.ct_config.controller_ign.*.rendered, count.index)}"
    destination = "/mnt/oem/config.ign"
  }

  provisioner "file" {
    content     = "COREOS_CUSTOM_PUBLIC_IPV4=${self.ipv4_address}"
    destination = "/mnt/root/etc/metadata/coreos"
  }

  provisioner "remote-exec" {
    inline = ["reboot"]
  }

  provisioner "remote-exec" {
    connection {
      user = "core"
    }

    inline = []
  }
}

# Controller Container Linux Config
data "template_file" "controller_config" {
  count = "${var.controller_count}"

  template = "${file("${path.module}/cl/controller.yaml.tmpl")}"

  vars = {
    ssh_keys = "${join("\n", values(var.ssh_keys))}"

    # Cannot use cyclic dependencies on controllers or their DNS records
    etcd_name   = "etcd${count.index}"
    etcd_domain = "${var.cluster_name}-etcd${count.index}.${var.dns_zone}"

    # etcd0=https://cluster-etcd0.example.com,etcd1=https://cluster-etcd1.example.com,...
    etcd_initial_cluster  = "${join(",", data.template_file.etcds.*.rendered)}"
    k8s_dns_service_ip    = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix = "${var.cluster_domain_suffix}"
  }
}

data "template_file" "etcds" {
  count    = "${var.controller_count}"
  template = "etcd$${index}=https://$${cluster_name}-etcd$${index}.$${dns_zone}:2380"

  vars {
    index        = "${count.index}"
    cluster_name = "${var.cluster_name}"
    dns_zone     = "${var.dns_zone}"
  }
}

data "ct_config" "controller_ign" {
  count        = "${var.controller_count}"
  content      = "${element(data.template_file.controller_config.*.rendered, count.index)}"
  pretty_print = false

  snippets = ["${var.controller_clc_snippets}"]
}
