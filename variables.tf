variable "project_id" {
  description = "The ID of the Google Cloud Platform project"
}

variable "region" {
  description = "The region where the resources will be created"
}
variable "vpc_config" {
  type        = map(any)
  description = "The VPC Configuration"
  default = {
    delete_default_routes_on_create = true
    auto_create_subnetworks         = false
    routing_mode                    = "REGIONAL"
  }
}

variable "subnets" {
  type = list(object({
    name                     = string
    ip_cidr_range            = string
    private_ip_google_access = bool
  }))
}

variable "webapp_route" {
  type        = map(any)
  description = "The webapp route configuration"
}

variable "webapp_route_tags" {
  type = list(string)
}

variable "webapp_route_priority" {
  type = string

}

variable "custom_image_family_name" {
  type = string
}

variable "vm_config" {
  description = "Configuration for the VM instance."
  type = object({
    name         = string
    machine_type = string
    zone         = string
    tags         = list(string)
    disk_type    = string
    disk_size    = number
    allow_http   = bool
    network_tier = string
    subnetwork   = string
  })
}


variable "allowport" {
  description = "Configuration of firewall for the VM instance."
  type = object({
    name          = string
    protocol      = string
    source_ranges = list(string)
    ports         = list(string)
    target_tags   = list(string)
    priority      = number
  })
}

variable "denyall" {
  description = "Configuration off firewall for the VM instance."
  type = object({
    name          = string
    protocol      = string
    source_ranges = list(string)
    priority      = number
  })
}

variable "cloudsql" {
  description = "Configuration options for the Cloud SQL instance."
  type = object({
    name               = string
    database_version   = string
    delete_protection  = bool
    tier               = string
    availability_type  = string
    disk_type          = string
    disk_size          = number
    psc_enabled        = bool
    ipv4_enabled       = bool
    binary_log_enabled = bool
    enabled            = bool
  })
}

variable "database" {
  type = object({
    name   = string
    port   = string
    host   = string
    user   = string
    subnet = string
  })
}

variable "address_type" {
  type = string
}

variable "dns_zone" {
  type = string
}
variable "webapp_password" {
  type = object({
    length  = string
    special = string
  })
}

variable "domain_record" {
  type = object({
    name = string
    type = string
    ttl  = number
  })
}

variable "service_account" {
  type = object({
    id           = string
    scopes       = list(string)
    display_name = string
    iam_bindings = list(string)
  })
}