provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "my_vpc" {
  name                    = var.vpc_config.name
  delete_default_routes_on_create = var.vpc_config.delete_default_routes_on_create
  auto_create_subnetworks = var.vpc_config.auto_create_subnetworks
  routing_mode            = var.vpc_config.routing_mode
}

output "vpc" {
  value = google_compute_network.my_vpc.self_link
}
