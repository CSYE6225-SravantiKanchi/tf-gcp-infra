provider "google" {
  project = var.project_id
  region  = var.region

}

resource "google_compute_network" "my_vpc" {
  name = var.vpc_config.name
  #to avoid creation of default route, we will mark it as false
  delete_default_routes_on_create = var.vpc_config.delete_default_routes_on_create
  auto_create_subnetworks         = var.vpc_config.auto_create_subnetworks
  routing_mode                    = var.vpc_config.routing_mode

}

resource "google_compute_subnetwork" "subnets" {
  for_each = { for idx, subnet in var.subnets : idx => subnet }

  name                     = each.value.name
  region                   = var.region
  network                  = google_compute_network.my_vpc.self_link
  ip_cidr_range            = each.value.ip_cidr_range
  private_ip_google_access = each.value.private_ip_google_access
}


resource "google_compute_route" "webapp_route" {
  name             = var.webapp_route.name
  network          = google_compute_network.my_vpc.self_link
  dest_range       = var.webapp_route.dest_range
  next_hop_gateway = var.webapp_route.next_hop_gateway
  priority         = 1000
  description      = "Route for webapp subnet"
  #Added this, to make the route accessible to the instaces which have this tag. Hence, we can create an unique tag for all the instances of webapp.
  tags = var.webapp_route_tags
}

data "google_compute_image" "my_image" {
  family      = var.custom_image_family_name
  most_recent = true
}
resource "google_compute_firewall" "allow_8080" {
  name    = var.allowport.name
  network = google_compute_network.my_vpc.name
  allow {
    protocol = var.allowport.protocol
    ports    = var.allowport.ports
  }

  source_ranges = var.allowport.source_ranges
  target_tags   = var.allowport.target_tags
}

resource "google_compute_instance" "vm_instance" {
  name         = var.vm_config.name
  machine_type = var.vm_config.machine_type
  zone         = var.vm_config.zone

  tags = var.vm_config.tags

  boot_disk {
    initialize_params {
      image = data.google_compute_image.my_image.self_link
      type  = var.vm_config.disk_type
      size  = var.vm_config.disk_size
    }
  }



  network_interface {
    network    = google_compute_network.my_vpc.name
    subnetwork = google_compute_subnetwork.subnets[0].name
    access_config {
      network_tier = var.vm_config.network_tier
    }
  }

  metadata = {
    "allow-http" = var.vm_config.allow_http ? "true" : "false"
  }
}

