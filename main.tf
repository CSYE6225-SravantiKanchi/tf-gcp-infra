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
  priority         = var.webapp_route_priority
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

  priority      = var.allowport.priority
  source_ranges = var.allowport.source_ranges
  target_tags   = var.allowport.target_tags
}

resource "google_compute_firewall" "deny_all" {
  name    = var.denyall.name
  network = google_compute_network.my_vpc.name
  deny {
    protocol = var.denyall.protocol
  }

  priority      = var.denyall.priority
  source_ranges = var.denyall.source_ranges
}

resource "google_compute_address" "default" {
  name         = "compute-address-${google_sql_database_instance.my_cloudsql_instance.name}"
  region       = var.region
  address_type = var.address_type
  subnetwork   = var.database.subnet
  address      = var.database.host
}


resource "google_sql_database_instance" "my_cloudsql_instance" {
  name                = var.cloudsql.name
  database_version    = var.cloudsql.database_version
  region              = var.region
  deletion_protection = var.cloudsql.delete_protection

  settings {
    tier              = var.cloudsql.tier
    availability_type = var.cloudsql.availability_type
    disk_type         = var.cloudsql.disk_type
    disk_size         = var.cloudsql.disk_size
    ip_configuration {
      psc_config {
        psc_enabled               = var.cloudsql.psc_enabled
        allowed_consumer_projects = [var.project_id]
      }
      ipv4_enabled = var.cloudsql.ipv4_enabled
    }

    backup_configuration {
      binary_log_enabled = var.cloudsql.binary_log_enabled
      enabled            = var.cloudsql.enabled
    }
  }
}




resource "google_compute_forwarding_rule" "default" {
  name                  = "forwarding-rule-${google_sql_database_instance.my_cloudsql_instance.name}"
  region                = var.region
  network               = google_compute_network.my_vpc.id
  ip_address            = google_compute_address.default.self_link
  load_balancing_scheme = ""
  target                = google_sql_database_instance.my_cloudsql_instance.psc_service_attachment_link
}


# Cloud SQL Database and User Configuration
resource "google_sql_database" "webapp_database" {
  name     = var.database.name
  instance = google_sql_database_instance.my_cloudsql_instance.name
}

resource "random_password" "webapp_password" {
  length  = var.webapp_password.length
  special = var.webapp_password.special
}

resource "google_sql_user" "webapp_user" {
  name     = var.database.user
  instance = google_sql_database_instance.my_cloudsql_instance.name
  password = random_password.webapp_password.result
}


#Service account for VM
resource "google_service_account" "default" {
  account_id   = var.service_account.id
  display_name = var.service_account.display_name
}


data "google_service_account" "vm_service_account" {
  account_id = var.service_account.id
  depends_on = [google_service_account.default]
}

#IAM Binding

resource "google_project_iam_binding" "iam_bindings" {
  for_each = { for idx, binding in var.service_account.iam_bindings : idx => binding }

  project = var.project_id
  role    = each.value

  members = [
    "serviceAccount:${data.google_service_account.vm_service_account.email}"
  ]
}

data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone
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
    subnetwork = var.vm_config.subnetwork
    access_config {
      network_tier = var.vm_config.network_tier
    }
  }

  metadata_startup_script = templatefile("${path.module}/script.sh.tpl", {
    name     = google_sql_user.webapp_user.name,
    password = google_sql_user.webapp_user.password
    host     = var.database.host
    port     = var.database.port
    database = var.database.name
  })

  depends_on = [google_service_account.default]

  service_account {
    email  = google_service_account.default.email
    scopes = var.service_account.scopes
  }
}

resource "google_dns_record_set" "domain_record" {
  name         = var.domain_record.name
  managed_zone = data.google_dns_managed_zone.dns_zone.name
  type         = var.domain_record.type
  ttl          = var.domain_record.ttl
  rrdatas      = [google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip]
}