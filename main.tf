terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.34.0"
    }
  }
}


provider "google" {
  project = var.project_id
  region  = var.region

}

provider "google-beta" {
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
  target_tags   = var.allowport.target_tags
  source_ranges = [google_compute_global_address.default.address]
  depends_on    = [google_compute_global_address.default]
}

resource "google_kms_key_ring" "my_key_ring" {
  name     = "my-key-ring"
  location = var.region
}

resource "google_kms_crypto_key" "vm_crypto_key" {
  name            = "vm-crypto-key"
  key_ring        = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s" # 30 days in seconds (30 * 24 * 60 * 60)
  depends_on      = [google_kms_key_ring.my_key_ring]
}

# Create a Customer-Managed Encryption Key (CMEK) for Cloud SQL Instances
resource "google_kms_crypto_key" "sql_crypto_key" {
  name            = "sql-crypto-key"
  key_ring        = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s" # 30 days in seconds (30 * 24 * 60 * 60)
  depends_on      = [google_kms_key_ring.my_key_ring]
}

# Create a Customer-Managed Encryption Key (CMEK) for Cloud Storage Buckets
resource "google_kms_crypto_key" "storage_crypto_key" {
  name            = "storage-crypto-key"
  key_ring        = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s" # 30 days in seconds (30 * 24 * 60 * 60)
  depends_on      = [google_kms_key_ring.my_key_ring]
}

resource "google_compute_firewall" "allow_healthz" {
  name    = var.allowport.healthzname
  network = google_compute_network.my_vpc.name
  allow {
    protocol = var.allowport.protocol
    ports    = var.allowport.ports
  }

  priority      = var.allowport.priority
  target_tags   = var.allowport.target_tags
  source_ranges = var.allowport.source_ranges
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

resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  service  = "sqladmin.googleapis.com"
}

resource "google_kms_crypto_key_iam_binding" "crypto_key" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.sql_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}",
  ]
}


resource "google_sql_database_instance" "my_cloudsql_instance" {
  name                = var.cloudsql.name
  database_version    = var.cloudsql.database_version
  region              = var.region
  deletion_protection = var.cloudsql.delete_protection
  encryption_key_name = google_kms_crypto_key.sql_crypto_key.id

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

  depends_on = [google_kms_crypto_key_iam_binding.crypto_key]
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

resource "google_compute_region_instance_template" "template" {
  name         = var.vm_config.name
  machine_type = var.vm_config.machine_type
  tags         = var.vm_config.tags
  metadata     = {}
  disk {
    source_image          = data.google_compute_image.my_image.self_link
    disk_type             = var.vm_config.disk_type
    disk_size_gb          = var.vm_config.disk_size
    auto_delete           = true
    boot                  = true
    labels                = {}
    resource_manager_tags = {}
    resource_policies     = []
    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_crypto_key.id
    }

    source_snapshot_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_crypto_key.id

    }
    source_image_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_crypto_key.id
    }

  }

  network_interface {
    network     = google_compute_network.my_vpc.name
    subnetwork  = var.vm_config.subnetwork
    queue_count = 0
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

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = var.autoscalar.name
  target = google_compute_region_instance_group_manager.appserver.self_link
  autoscaling_policy {
    min_replicas = var.autoscalar.min
    max_replicas = var.autoscalar.max
    cpu_utilization {
      target = var.autoscalar.cpu_utilization_target
    }
  }
}



resource "google_compute_health_check" "autohealing" {
  name                = var.autohealing.name
  check_interval_sec  = var.autohealing.check_interval_sec
  timeout_sec         = var.autohealing.timeout_sec
  healthy_threshold   = var.autohealing.healthy_threshold
  unhealthy_threshold = var.autohealing.unhealthy_threshold
  http_health_check {
    request_path = var.autohealing.request_path
    port         = var.autohealing.port
  }
}



resource "google_compute_region_instance_group_manager" "appserver" {
  name                             = var.MIG.name
  base_instance_name               = var.MIG.base_instance_name
  distribution_policy_zones        = var.MIG.distributions
  version {
    instance_template = google_compute_region_instance_template.template.self_link
  }
  target_size = var.MIG.target_size
  named_port {
    name = var.MIG.portname
    port = var.MIG.port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = var.MIG.initial_delay_sec
  }

  depends_on = [google_compute_region_instance_template.template]
}

# reserved IP address
resource "google_compute_global_address" "default" {
  provider = google-beta
  name     = var.lb_address
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = var.ssl.name

  managed {
    domains = var.ssl.domains
  }
}


# https proxy
resource "google_compute_target_https_proxy" "default" {
  count            = 1
  name             = var.https_proxy
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.name]
}

#url mapping
resource "google_compute_url_map" "default" {
  name            = var.url_map
  provider        = google-beta
  default_service = google_compute_backend_service.default.id
}


resource "google_compute_global_forwarding_rule" "https" {
  provider   = google-beta
  count      = 1
  name       = var.lb_forwarding_rule.name
  target     = google_compute_target_https_proxy.default[0].self_link
  ip_address = google_compute_global_address.default.address
  port_range = var.lb_forwarding_rule.port_range
  depends_on = [google_compute_global_address.default]

  labels = {}
}

resource "google_compute_backend_service" "default" {
  name                  = var.backend.name
  provider              = google-beta
  protocol              = var.backend.protocol
  port_name             = var.backend.port_name
  load_balancing_scheme = var.backend.load_balancing_scheme
  timeout_sec           = var.backend.timeout_sec
  health_checks         = [google_compute_health_check.autohealing.id]
  backend {
    group           = google_compute_region_instance_group_manager.appserver.instance_group
    balancing_mode  = var.backend.balancing_mode
    capacity_scaler = var.backend.capacity_scaler
  }
}


resource "google_dns_record_set" "domain_record" {
  name         = var.domain_record.name
  managed_zone = data.google_dns_managed_zone.dns_zone.name
  type         = var.domain_record.type
  ttl          = var.domain_record.ttl
  rrdatas      = [google_compute_global_address.default.address]
}


# Create Pub Sub Topic, and IAM Binding

resource "google_service_account" "pubsub_topic_service_account" {
  account_id   = var.pubsub_topic.account_id
  display_name = var.pubsub_topic.display_name
}

resource "google_pubsub_topic_iam_binding" "pubsub_topic_role_binding" {
  topic = google_pubsub_topic.topic.name
  role  = var.pubsub_topic.role
  members = [
    "serviceAccount:${google_service_account.pubsub_topic_service_account.email}"
  ]
}
resource "google_pubsub_topic" "topic" {
  name                       = var.pubsub_topic.name
  message_retention_duration = var.pubsub_topic.message_retention_duration
}


# #Create Subscription and IAM Binding
resource "google_service_account" "pubsub_subscription_service_account" {
  account_id   = var.pubsub_subscription.account_id
  display_name = var.pubsub_subscription.display_name
}

resource "google_pubsub_subscription" "verify_email_subscription" {
  name                 = var.pubsub_subscription.name
  topic                = google_pubsub_topic.topic.name
  ack_deadline_seconds = var.pubsub_subscription.ack_deadline_seconds
}


resource "google_pubsub_subscription_iam_binding" "pubsub_subscription_role_binding" {
  role         = var.pubsub_subscription.role
  subscription = google_pubsub_subscription.verify_email_subscription.name
  members = [
    "serviceAccount:${google_service_account.pubsub_subscription_service_account.email}"
  ]
}

#Create Cloud Function IAM Binding

resource "google_service_account" "cloud_function_service_account" {
  account_id   = var.pubsub_cloudfunction.account_id
  display_name = var.pubsub_cloudfunction.display_name
}




data "archive_file" "cloud_function_zip" {
  type        = "zip"
  source_dir  = var.archive_dir.source_dir
  output_path = var.archive_dir.output_path
}

resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.cloud_function_zip.output_path
  content_type = "application/zip"
  name         = "src-${data.archive_file.cloud_function_zip.output_md5}.zip"
  bucket       = google_storage_bucket.Cloud_function_bucket.name
  depends_on = [
    google_storage_bucket.Cloud_function_bucket,
    data.archive_file.cloud_function_zip
  ]
}

resource "google_storage_bucket" "Cloud_function_bucket" {
  name     = var.cbucket
  location = var.region
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_crypto_key.name
  }
}

resource "google_vpc_access_connector" "cloud_function_vpc_connector" {
  name          = var.vpc_connector.name
  region        = var.region
  network       = google_compute_network.my_vpc.name
  ip_cidr_range = var.vpc_connector.ip_cidr_range
}


# IAM entry for all users to invoke the function
resource "google_project_iam_binding" "cloudsql_client_binding" {
  project = var.project_id
  role    = var.pubsub_cloudfunction.sqlrole
  members = [
    "serviceAccount:${google_service_account.cloud_function_service_account.email}"
  ]
}


resource "google_cloud_run_service_iam_binding" "role1_member" {
  project = var.project_id
  role    = var.pubsub_cloudfunction.role
  service = google_cloudfunctions2_function.Cloud_function.name
  members = [
    "serviceAccount:${google_service_account.cloud_function_service_account.email}"
  ]
}

resource "google_cloudfunctions2_function" "Cloud_function" {
  name        = var.cloudfunction.name
  location    = var.region
  description = var.cloudfunction.description

  build_config {
    runtime     = var.cloudfunction.runtime
    entry_point = var.cloudfunction.entry_point # Set the entry point
    source {
      storage_source {
        bucket = google_storage_bucket.Cloud_function_bucket.name
        object = google_storage_bucket_object.zip.name
      }
    }

  }

  event_trigger {
    event_type            = var.cloudfunction.event_type
    trigger_region        = var.region
    pubsub_topic          = google_pubsub_topic.topic.id
    retry_policy          = var.cloudfunction.retry_policy
    service_account_email = google_service_account.cloud_function_service_account.email
  }

  service_config {
    max_instance_count            = var.cloudfunction.max_instance_count
    available_memory              = var.cloudfunction.available_memory
    timeout_seconds               = var.cloudfunction.timeout_seconds
    service_account_email         = google_service_account.cloud_function_service_account.email
    vpc_connector                 = google_vpc_access_connector.cloud_function_vpc_connector.name
    vpc_connector_egress_settings = var.cloudfunction.vpc_connector_egress_settings
    environment_variables = {
      MAILGUN_USER     = var.cloudfunction_env.mailgun_user
      MAILGUN_PASSWORD = var.cloudfunction_env.mailgun_password
      SQL_USER         = google_sql_user.webapp_user.name,
      SQL_PASSWORD     = google_sql_user.webapp_user.password
      SQL_HOST         = var.database.host
      SQL_DB           = var.database.name
    }
  }


  depends_on = [
    google_storage_bucket.Cloud_function_bucket,
    google_storage_bucket_object.zip
  ]
}
