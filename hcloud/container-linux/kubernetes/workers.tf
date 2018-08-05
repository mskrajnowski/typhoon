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

  user_data = "${data.ct_config.worker_ign.rendered}"
  ssh_keys  = ["${var.ssh_fingerprints}"]
}

# Worker Container Linux Config
data "template_file" "worker_config" {
  template = "${file("${path.module}/cl/worker.yaml.tmpl")}"

  vars = {
    k8s_dns_service_ip    = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix = "${var.cluster_domain_suffix}"
  }
}

data "ct_config" "worker_ign" {
  content      = "${data.template_file.worker_config.rendered}"
  pretty_print = false
  snippets     = ["${var.worker_clc_snippets}"]
}
