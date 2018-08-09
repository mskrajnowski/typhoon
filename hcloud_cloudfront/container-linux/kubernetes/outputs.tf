output "controllers_dns" {
  value = "${cloudflare_record.controllers.0.hostname}"
}

output "workers_dns" {
  value = "${cloudflare_record.workers.0.hostname}"
}

output "controllers_ipv4" {
  value = ["${hcloud_server.controllers.*.ipv4_address}"]
}

output "controllers_ipv6" {
  value = ["${hcloud_server.controllers.*.ipv6_address}"]
}

output "workers_ipv4" {
  value = ["${hcloud_server.workers.*.ipv4_address}"]
}

output "workers_ipv6" {
  value = ["${hcloud_server.workers.*.ipv6_address}"]
}
