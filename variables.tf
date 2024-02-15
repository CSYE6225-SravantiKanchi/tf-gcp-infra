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
    name          = string
    ip_cidr_range = string
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
