# Worker DNS records
resource "cloudflare_record" "workers" {
  count = "${var.worker_count}"

  # DNS zone where record should be created
  domain = "${var.dns_zone}"

  name  = "${var.cluster_name}-workers"
  type  = "A"
  ttl   = 300
  value = "${element(hcloud_server.workers.*.ipv4_address, count.index)}"
}

# Worker droplet instances
resource "hcloud_server" "workers" {
  count = "${var.worker_count}"

  name     = "${var.cluster_name}-worker-${count.index}"
  location = "${var.location}"

  image       = "${var.image}"
  server_type = "${var.worker_type}"

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
    content     = "${data.ct_config.worker_ign.rendered}"
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

# Worker Container Linux Config
data "template_file" "worker_config" {
  template = "${file("${path.module}/cl/worker.yaml.tmpl")}"

  vars = {
    ssh_keys              = "${join("\n", values(var.ssh_keys))}"
    k8s_dns_service_ip    = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix = "${var.cluster_domain_suffix}"
  }
}

data "ct_config" "worker_ign" {
  content      = "${data.template_file.worker_config.rendered}"
  pretty_print = false
  snippets     = ["${var.worker_clc_snippets}"]
}
