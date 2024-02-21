# Terraform VPC Creation Guide

## Overview

This README provides instructions for creating a VPC, subnets, and one route specific to a subnet in GCP.

## Prerequisites

- Sign up for GCP.
- Create a Project.
- Disable all the unnecessary APIs.
- Enable the Compute Engine API, which we will be using for resource creation using Terraform.

## Local Setup

- Clone the repo of the main branch.
- Set up gcloud.
- Switch to the created project in gcloud,

```bash
gcloud auth login
gcloud config set project [PROJECT_ID]
```
- Authenticate, which will be used by Terraform for resource creation.

  ```bash
    gcloud auth application-default login
  ```
   
- we can enable compute engine via gcloud cli as well
    ```bash
    gcloud services enable compute.googleapis.com
    ```


### Infrastructure Components
#### 1. VPC
A VPC is created to host the infrastructure, providing an isolated network environment.

#### 2. Subnets: Two subnets are configured within the VPC:
Web Application Subnet: Hosts the web application instances, enabling them to serve traffic to and from the internet.
Database Subnet: Isolated environment for database instances, enhancing security by restricting direct access from the internet.

#### 3. Custom Route for Web Application
A custom route is defined specifically for the web application subnet. This route enables outbound traffic to the internet, ensuring that the web application can communicate with external services and users, adding a tag to make sure that tag-specific instances can only communicate with external services.

#### 4. Firewall Rules
To secure the network traffic:

Allow Specific Port: A firewall rule is added to allow inbound traffic on the application's port. This rule is crucial for enabling users to access the web application.
Deny All Traffic: A default rule to deny all other inbound traffic is established, minimizing the exposure to unauthorized access and potential attacks.

### Terraform variables configuration

create a terraform.tfvars file, and configure the variables with the required setup

```bash
project_id = "test-project"
region     = "required region"
vpc_config = {
  name                            = "vpc-name"  // Name of the VPC
  delete_default_routes_on_create = true/false   // Whether to delete default routes upon creation
  auto_create_subnetworks         = true/false   // Auto-creation of subnetworks
  routing_mode                    = "required mode" // Routing mode, either "REGIONAL" or "GLOBAL"
}

subnets = [
  {
    name          = "subnet1"
    ip_cidr_range = "required range"
    private_ip_google_access = true/false
  },
  ....
]

webapp_route = {
  name             = "custom route"
  dest_range       = "required range"
  next_hop_gateway = "required gateway"
}

webapp_route_tags = [
  "unique tag which we will be adding to the webapp specific instances"
]

webapp_route_priority = "test-priority"  // Adjust the priority as needed. Lower numbers indicate higher priority.

custom_image_family_name = "test-image-family"  // add the name of your custom image family here.

vm_config = {
  name         = "test-vm-name"       // Name of the VM instance.
  machine_type = "test-machine-type"  // Specify the machine type (e.g., "e2-medium").
  zone         = "test-zone"          // The zone for VM deployment.
  tags         = ["test-tag"]         // Network tags for applying firewall and routing rules.
  disk_type    = "test-disk-type"     // Boot disk type (e.g., "pd-standard", "pd-ssd").
  disk_size    = "test-disk-size"     // Size of the boot disk in GB.
  network_tier = "test-network-tier"  // Network tier (e.g., "PREMIUM").
  subnetwork   = "test-subnetwork"    // Subnetwork name for the VM.
}

allowport = {
  name          = "test-rule-name-allow"  // Name of the firewall rule.
  ports         = ["test-port"]           // Port numbers to allow (e.g., [8080]).
  protocol      = "test-protocol"         // Protocol to allow (e.g., "tcp").
  source_ranges = ["test-source-range"]   // ranges allowed to connect.
  target_tags   = ["test-target-tag"]     // Apply the rule to instances with this tag.
  priority      = "test-priority-allow"   // Rule priority.
}

denyall = {
  name          = "test-rule-name-deny"  // Name of the deny all traffic rule.
  protocol      = "all"   // Typically "all" to deny all protocols.
  source_ranges = ["test-source-range"]  //range to apply the deny rule.
  priority      = "test-priority-deny"   // Rule priority, higher than allow rules.
}

```

### Terraform Commands

After Configuring the tfvars,

1. Initialize Terraform to download all the required libraries.

```bash
terraform init
````
2. Terraform workspace is useful to maintain different states for different resources. For example, if we want to create multiple VPCs, then we can create a different workspace for each VPC, which will not destroy the existing VPCs and will also maintain the states of each created VPC in their corresponding workspace. (https://developer.hashicorp.com/terraform/language/state/workspaces)

```bash
terraform workspace 'vpc workspace name'
terraform workspace select 'vpc workspace name'
```

3.Review the plan of creation/destroy/replacement using the below command.

```bash
terraform plan --var-file='use this only if the tfvars name is not terraform.tfvars'
```
4. Post-review, apply the changes using the below command.

```bash
terraform apply
```

### Conclusion

Follow these step, once done revoke the auth to avoid security issues
- Once done, revoke the auth login.

    ```bash
    gcloud auth revoke
    gcloud auth application-default revoke
    ```
