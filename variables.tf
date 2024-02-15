variable "project_id" {
  description = "The ID of the Google Cloud Platform project"
}

variable "region" {
  description = "The region where the resources will be created"
}
variable "vpc_config" {
  type = map
  description = "The VPC Configuration"
  default = {
    delete_default_routes_on_create = true
    auto_create_subnetworks = false
    routing_mode            = "REGIONAL"
  }
}

