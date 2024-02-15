provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "my_vpc" {
  name                            = var.vpc_config.name
  delete_default_routes_on_create = var.vpc_config.delete_default_routes_on_create
  auto_create_subnetworks         = var.vpc_config.auto_create_subnetworks
  routing_mode                    = var.vpc_config.routing_mode

}

resource "google_compute_subnetwork" "subnets" {
  for_each = { for idx, subnet in var.subnets : idx => subnet }

  name          = each.value.name
  region        = var.region
  network       = google_compute_network.my_vpc.self_link
  ip_cidr_range = each.value.ip_cidr_range
}


resource "google_compute_route" "webapp_route" {
  name             = var.webapp_route.name
  network          = google_compute_network.my_vpc.self_link
  dest_range       = var.webapp_route.dest_range
  next_hop_gateway = var.webapp_route.next_hop_gateway
  priority         = 1000
  description      = "Route for webapp subnet"
  tags             = ["webapp"]

}

